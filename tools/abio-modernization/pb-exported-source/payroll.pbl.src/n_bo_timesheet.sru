$PBExportHeader$n_bo_timesheet.sru
forward
global type n_bo_timesheet from n_cst_business_abio
end type
end forward

global type n_bo_timesheet from n_cst_business_abio
end type
global n_bo_timesheet n_bo_timesheet

type variables

n_bo_area					ibo_area
n_bo_centre					ibo_centre
n_bo_book					ibo_book
n_bo_trade_union			ibo_trade_union
n_bo_trade_union_rate	ibo_trade_union_rate
n_bo_occupation			ibo_occupation
n_bo_occupation_rate		ibo_occupation_rate

//used for validating premiums
n_bo_premium_type				ibo_premium_type
n_bo_timesheet_premium		ibo_timesheet_premium
n_bo_employee_premium		ibo_employee_premium
n_bo_trade_union_premium	ibo_trade_union_premium

string		is_jc_labour_cost

Boolean		ib_centres_must_be_open = TRUE

end variables

forward prototypes
public function integer of_get_last_paid_timesheet (string as_book, long al_employee, ref date adt_work)
public function integer of_get_last_timesheet_since (string as_book, long al_employee, date adt_since, ref date adt_work)
public function integer of_get_last_timesheet_with_hours_since (string as_book, long al_employee, date adt_since, ref date adt_work)
public function integer of_get_timesheet_subtotals (string as_book, long al_employee, datetime adt_work_date, integer ai_timesheet_item, long al_cheque, ref s_timesheet astr_timesheet, ref decimal adec_daily_hours, ref string as_error_message)
public function integer of_get_next_ts_item (long al_employee, datetime adt_work)
public function integer of_format_template_for_job_and_crew (oleobject aoo_excel, string as_path, ref string as_file_created, n_ds ads_export, string as_book, date adt_work_date, string as_job, string as_crew_description, string as_crew_id, string as_supervisor, string as_approver, string as_scheduled, boolean ab_generate_unique_filename)
public function integer of_validate_premiums (ref n_ds ads_msg, ref hprogressbar a_hpb)
public function datetime of_convert_date (string as_date)
public function integer of_insert_issl_timesheets (string as_file, ref string as_memo, ref datetime adt_work_from, ref datetime adt_work_to, ref n_bo_timesheet_premium abo_timesheet_premium)
public function integer of_check_pay_period (string as_pr_yyyymm, ref string as_msg)
protected function string of_generatedelta (dwbuffer ae_buffer, long al_row)
end prototypes

public function integer of_get_last_paid_timesheet (string as_book, long al_employee, ref date adt_work);
//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_get_last_paid_timesheet
// Author   :	Monica Petersen
// Date     :	2009/10/05
// 	
// Arguments:	string as_book
// 				long al_employee
// 				date adt_work
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

Int		li_return
Long		ll_row

SetNull(adt_work)

SELECT TOP 1 work_date
  INTO :adt_work
FROM (SELECT work_date, 
				 sum(reg_hour) as daily_reg, 
				 sum(ovr_hour) as daily_ovr, 
				 sum(tah_hour) as daily_tah
		  FROM timesheet
		 WHERE book 		= :as_book
			AND employee 	= :al_employee
			AND cheque_no <> 0
	    GROUP BY work_date) daily_summary
WHERE daily_summary.daily_reg <> 0
   OR daily_summary.daily_ovr <> 0
   OR daily_summary.daily_tah <> 0
ORDER BY work_date DESC
USING sqlca;
CHOOSE CASE sqlca.sqlcode 
	CASE -1 
		li_return = -1
	CASE 100
		li_return = 0
	CASE 0
		li_return = 1
END CHOOSE

//IF as_book = '' OR al_employee = 0 THEN
//	li_return = -1
//ELSE
//	ll_row = This.of_retrieve("book = '" + as_book + "' AND employee = " + String(al_employee) + " AND cheque_no <> 0")
//	IF ll_row > 0 THEN
//		this.of_SetSort("work_date DESC")
//		this.of_Sort()
//		li_return = 1
//		adt_work = Date(this.of_GetItemDateTime(1, 'work_date'))
//	ELSE
//		li_return = 0
//	END IF
//END IF

RETURN li_return
end function

public function integer of_get_last_timesheet_since (string as_book, long al_employee, date adt_since, ref date adt_work);
//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_get_last_timesheet_since
// Author   :	Monica Petersen
// Date     :	2009/10/08
// 	
// Arguments:	string as_book
// 				long al_employee
// 				date adt_since
// 				date adt_work
// 	
// Returns:		integer
// 	
// Desc:			Built for the timesheet entry screen.
//					It uses the last_worked_date on the 
//					employee record to narrow the search
//					for the latest timesheet before the one being keyed
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Int		li_return
Long		ll_row

SetNull(adt_work)

IF as_book = '' OR al_employee = 0 THEN
	li_return = -1
ELSE
	ll_row = This.of_retrieve("book = '" + as_book + "' AND employee = " + String(al_employee) + " AND work_date > '" + String(adt_since, 'yyyy.mm.dd') + "'")
	IF ll_row > 0 THEN
		this.of_SetSort("work_date DESC")
		this.of_Sort()
		li_return = 1
		adt_work = Date(this.of_GetItemDateTime(1, 'work_date'))
	ELSE
		li_return = 0
	END IF
END IF

RETURN li_return
end function

public function integer of_get_last_timesheet_with_hours_since (string as_book, long al_employee, date adt_since, ref date adt_work);
//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_get_last_timesheet_with_hours_since
// Author   :	Monica Petersen
// Date     :	2014/06/13
// 	
// Arguments:	string as_book
// 				long al_employee
// 				date adt_since
// 				date adt_work
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


Int		li_return
Long		ll_row

SetNull(adt_work)

IF as_book = '' OR al_employee = 0 THEN
	li_return = -1
ELSE
	ll_row = This.of_retrieve("book = '" + as_book &
									+ "' AND employee = " + String(al_employee) &
									+ " AND work_date > '" + String(adt_since, 'yyyy.mm.dd') &
									+ "' AND cheque_no = 0 AND (reg_hour > 0 OR ovr_hour > 0 OR tah_hour > 0 OR travel_hour > 0)")
	IF ll_row > 0 THEN
		this.of_SetSort("work_date DESC")
		this.of_Sort()
		li_return = 1
		adt_work = Date(this.of_GetItemDateTime(1, 'work_date'))
	ELSE
		li_return = 0
	END IF
END IF

RETURN li_return

//SELECT TOP 1 work_date
//  INTO :adt_work
//FROM (SELECT work_date, 
//				 sum(reg_hour) as daily_reg, 
//				 sum(ovr_hour) as daily_ovr, 
//				 sum(tah_hour) as daily_tah
//		  FROM timesheet
//		 WHERE book 		= :as_book
//			AND employee 	= :al_employee
//			AND (work_date  > :adt_since OR :adt_since IS NULL)
//	    GROUP BY work_date) daily_summary
//WHERE daily_summary.daily_reg > 0
//   OR daily_summary.daily_ovr > 0
//   OR daily_summary.daily_tah > 0
//ORDER BY work_date DESC
//USING sqlca;
//CHOOSE CASE sqlca.sqlcode 
//	CASE -1
//		li_return = -1
//	CASE 100
//		//No later timesheets found, this must be the latest.
//		adt_work = adt_since
//		li_return = 0
//	CASE 0
//		li_return = 1
//END CHOOSE



RETURN li_return
end function

public function integer of_get_timesheet_subtotals (string as_book, long al_employee, datetime adt_work_date, integer ai_timesheet_item, long al_cheque, ref s_timesheet astr_timesheet, ref decimal adec_daily_hours, ref string as_error_message);//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_get_timesheet_subtotals
// Author   :	Monica Petersen
// Date     :	26JUN2007
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_work_date
// 				integer ai_timesheet_item
// 				long al_cheque
// 				s_timesheet astr_timesheet
// 				decimal adec_daily_hours
// 				string as_error_message
// 	
// Returns:		integer
// 	
// Desc:			Get the totals for all the other timesheets 
//					on this same cheque for this employee
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

//How many hours worked today
SELECT sum(reg_hour) + sum(tah_hour) + sum(ovr_hour) + sum(travel_hour)
  INTO :adec_daily_hours
  FROM timesheet
 WHERE book 				= :gnv_app.is_book
	AND employee			= :al_employee
	AND work_date	 		= :adt_work_date 
	AND file_type 			= 'C'
	AND timesheet_item  <> :ai_timesheet_item
USING sqlca;
CHOOSE CASE sqlca.sqlcode
	CASE -1
		as_error_message = "Error getting " + String(adt_work_date) + " timesheet subtotals"
		RETURN -1
	CASE 100
		adec_daily_hours = 0
END CHOOSE

IF IsNull(adec_daily_hours) THEN
	adec_daily_hours = 0
END IF

//Totals for this cheque
SELECT sum(reg_hour),
		sum(tah_hour),
		sum(ovr_hour),
		sum(travel_hour),
		sum(loa_hour),
		sum(mileage_hour),
		sum(reg_earn),
		sum(tah_earn),
		sum(ovr_earn),
		sum(travel_earn),
		sum(loa),
		sum(mileage),
		sum(turnaround),
		sum(meal),
		sum(taxi),
		sum(retro),
		sum(vehicle_allowance_paid),
		sum(other_taxable_pay),
		sum(total),
		sum(fringe),
		sum(site_allowance),
		sum(gst_amount),
		sum(pay_in_lieu_of_notice)
  INTO :astr_timesheet.dec_reg_hour,
		:astr_timesheet.dec_tah_hour,
		:astr_timesheet.dec_ovr_hour,
		:astr_timesheet.dec_travel_hour,
		:astr_timesheet.dec_loa_hour,
		:astr_timesheet.dec_mileage_hour,
		:astr_timesheet.dec_reg_earn,
		:astr_timesheet.dec_tah_earn,
		:astr_timesheet.dec_ovr_earn,
		:astr_timesheet.dec_travel_earn,
		:astr_timesheet.dec_loa,
		:astr_timesheet.dec_mileage,
		:astr_timesheet.dec_turnaround,
		:astr_timesheet.dec_meal,
		:astr_timesheet.dec_taxi,
		:astr_timesheet.dec_retro,
		:astr_timesheet.dec_vehicle,
		:astr_timesheet.dec_other_taxable_pay,
		:astr_timesheet.dec_total,
		:astr_timesheet.dec_fringe,
		:astr_timesheet.dec_site_allowance,
		:astr_timesheet.dec_gst_amount,
		:astr_timesheet.dec_pay_in_lieu_of_notice
  FROM timesheet
 WHERE book 				= :gnv_app.is_book
	AND employee			= :al_employee
	AND cheque_no	 		= :al_cheque 
	AND file_type 			= 'C'
	AND Not(timesheet_item  = :ai_timesheet_item AND work_date = :adt_work_date)
USING sqlca;
CHOOSE CASE sqlca.sqlcode
	CASE -1
		as_error_message = "Error getting cheque " + String(al_cheque) + " totals"
		RETURN -1
	CASE 100
		astr_timesheet.dec_reg_hour = 0
		astr_timesheet.dec_tah_hour = 0
		astr_timesheet.dec_ovr_hour = 0
		astr_timesheet.dec_travel_hour = 0
		astr_timesheet.dec_loa_hour = 0
		astr_timesheet.dec_mileage_hour = 0
		astr_timesheet.dec_reg_earn = 0
		astr_timesheet.dec_tah_earn = 0
		astr_timesheet.dec_ovr_earn = 0
		astr_timesheet.dec_travel_earn = 0
		astr_timesheet.dec_loa = 0
		astr_timesheet.dec_mileage = 0
		astr_timesheet.dec_turnaround = 0
		astr_timesheet.dec_meal = 0
		astr_timesheet.dec_taxi = 0
		astr_timesheet.dec_retro = 0
		astr_timesheet.dec_vehicle = 0
		astr_timesheet.dec_other_taxable_pay = 0
		astr_timesheet.dec_total = 0
		astr_timesheet.dec_fringe = 0
		astr_timesheet.dec_site_allowance = 0
		astr_timesheet.dec_pay_in_lieu_of_notice = 0
END CHOOSE

IF IsNull(astr_timesheet.dec_reg_hour) THEN
	astr_timesheet.dec_reg_hour = 0
	astr_timesheet.dec_tah_hour = 0
	astr_timesheet.dec_ovr_hour = 0
	astr_timesheet.dec_travel_hour = 0
	astr_timesheet.dec_loa_hour = 0
	astr_timesheet.dec_mileage_hour = 0
	astr_timesheet.dec_reg_earn = 0
	astr_timesheet.dec_tah_earn = 0
	astr_timesheet.dec_ovr_earn = 0
	astr_timesheet.dec_travel_earn = 0
	astr_timesheet.dec_loa = 0
	astr_timesheet.dec_mileage = 0
	astr_timesheet.dec_turnaround = 0
	astr_timesheet.dec_meal = 0
	astr_timesheet.dec_taxi = 0
	astr_timesheet.dec_retro = 0
	astr_timesheet.dec_vehicle = 0
	astr_timesheet.dec_other_taxable_pay = 0
	astr_timesheet.dec_total = 0
	astr_timesheet.dec_fringe = 0
	astr_timesheet.dec_site_allowance = 0
	astr_timesheet.dec_gst_amount = 0
	astr_timesheet.dec_pay_in_lieu_of_notice = 0
END IF

RETURN 1
end function

public function integer of_get_next_ts_item (long al_employee, datetime adt_work);
Long	li_max_item

//Find next item number
SELECT MAX(timesheet_item)
  INTO :li_max_item
  FROM timesheet
 WHERE book 		= :gnv_app.is_book
	AND employee 	= :al_employee
	AND work_date 	= :adt_work
 USING sqlca;
IF sqlca.sqlcode <> 0 THEN
	gnv_app.of_msg_db_error("PRCENT", "Error reading timesheet")
	RETURN -1
END IF
IF IsNull(li_max_item) THEN li_max_item = 0

RETURN li_max_item + 1
end function

public function integer of_format_template_for_job_and_crew (oleobject aoo_excel, string as_path, ref string as_file_created, n_ds ads_export, string as_book, date adt_work_date, string as_job, string as_crew_description, string as_crew_id, string as_supervisor, string as_approver, string as_scheduled, boolean ab_generate_unique_filename);//************************************************************
// Object   :	w_report_preview_cc 
// Function :	of_format_template_for_job_and_crew
// Author   :	Monica Petersen
// Date     :	2015/10/15
// 	
// Arguments:	oleobject aoo_excel
// 				string as_path
// 				string as_file_created
// 				n_ds ads_export
// 				string as_book
// 				date adt_work_date
// 				string as_job
// 				string as_crew
// 				string as_supervisor
// 				string as_approver
// 				string as_scheduled
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

Long			ll_rowcount, ll_spreadsheet_row, ll_x, ll_column
String		ls_total_st[], ls_total_ot[], ls_total_spot[]
String		ls_last_name, ls_filename
String		ls_names[], ls_path[], ls_crew[]
String		xlContinuous = '1'
Long			xlSum = -4157
Long			xlSolid = 1
Long			xlAutomatic = -4105
Long			xlToLeft = -4159
Long			xlCenter = -4108
Long			xlLeft = -4131
Long			xlRight  = -4152
Long			xColorGrey = RGB(238,238,238)
Long			xlNone = -4142
Long			xlHairline = 1
Long			xlThin = 2
Long			xlMedium = -4138
Long			xlThick = 4
Long			xlEdgeLeft = 7
Long			xlEdgeTop = 8
Long			xlEdgeBottom = 9
Long			xlEdgeRight = 10
Long			xlDiagonalUp = 6
Long			xlDiagonalDown = 5
Long			xlInsideVertical = 11
Long			xlInsideHorizontal = 12
Long			xlLastCell = 11
Long			ll_last_row

		
aoo_excel.workbooks.Add

//Company Name
aoo_excel.Range('C1').Value = f_get_company_name(as_book)
aoo_excel.Range('C1:L1').MergeCells = True
aoo_excel.Range("C1:L1").HorizontalAlignment = xlCenter

//Left justify selection criteria
aoo_excel.Range("A3:B7").HorizontalAlignment = xlRight
aoo_excel.Range("C3:G7").HorizontalAlignment = xlLeft

//ID box
aoo_excel.Range('A3').Value = "Work Date"
aoo_excel.Range('A3:B3').MergeCells = True
aoo_excel.Range('C3:G3').MergeCells = True
aoo_excel.Range("A3:B3").HorizontalAlignment = xlRight
aoo_excel.Range('C3').Value = String(adt_work_date, 'dddd, yyyy.mm.dd')

aoo_excel.Range('A4').Value = "Job"
aoo_excel.Range('A4:B4').MergeCells = True
aoo_excel.Range('C4:G4').MergeCells = True
aoo_excel.Range("A4:B4").HorizontalAlignment = xlRight
aoo_excel.Range('C4').Value = as_job

aoo_excel.Range('A5').Value = "Crew"
aoo_excel.Range('A5:B5').MergeCells = True
aoo_excel.Range('C5:G5').MergeCells = True
aoo_excel.Range("A5:B5").HorizontalAlignment = xlRight

//Crew id is expected as the last word in the crew description
gnv_app.inv_string.of_ParseToArray(as_crew_description, '.', ls_crew)
IF UpperBound(ls_crew) > 0 THEN
	IF ls_crew[UpperBound(ls_crew)] <> as_crew_id THEN
		as_crew_description += ' ' + as_crew_id
	END IF
END IF
aoo_excel.Range('C5').Value = as_crew_description	

aoo_excel.Range('A6').Value = "Supervisor"
aoo_excel.Range('A6:B6').MergeCells = True
aoo_excel.Range('C6:G6').MergeCells = True
aoo_excel.Range("A6:B6").HorizontalAlignment = xlRight
aoo_excel.Range('C6').Value = as_supervisor

aoo_excel.Range('A7').Value = "Approver"
aoo_excel.Range('A7:B7').MergeCells = True
aoo_excel.Range('C7:G7').MergeCells = True
aoo_excel.Range("A7:B7").HorizontalAlignment = xlRight
aoo_excel.Range('C7').Value = as_approver

//we're going to blend scheduled and unscheduled, so leave off the description
//aoo_excel.Range('A12').Value = as_scheduled

//Ticket Number
IF ads_export.GetItemString(1, 'update_last_timesheet') = 'Y' THEN
	aoo_excel.Range('N3').Value = 'Ticket'
	aoo_excel.Range("N3:O3").HorizontalAlignment = xlRight
	aoo_excel.Range('O3').Value = ads_export.GetItemString(1, 'ticket_no')
	//Surround ticket with borders
	aoo_excel.Range("N3:O3").Borders.LineStyle = xlContinuous
	//and some colour...
	aoo_excel.Range("N3").Interior.Pattern = xlSolid
	aoo_excel.Range("N3").Interior.PatternColorIndex = xlAutomatic
	aoo_excel.Range("N3").Interior.Color = xColorGrey
END IF

//Surround selection criteria box with borders
aoo_excel.Range("A3:G7").Borders.LineStyle = xlContinuous

//Column headings
aoo_excel.Range('C9').Value = "JOB"
aoo_excel.Range('C10').Value = "AREA"
aoo_excel.Range('C11').Value = "CODE"
aoo_excel.Range('C12').Value = "DESCRIPTION"
aoo_excel.Range('N9').Value = 'TOTAL'
aoo_excel.Range('N9:N11').MergeCells = True
aoo_excel.Range('O9').Value = 'COMMENT'
aoo_excel.Range('O9:O11').MergeCells = True
 
//Column Widths
aoo_excel.Columns("A:A").ColumnWidth = 16.5
aoo_excel.Columns("B:B").ColumnWidth = 6.5
aoo_excel.Columns("C:C").ColumnWidth = 12.0
aoo_excel.Columns("D:N").ColumnWidth = 6.5
aoo_excel.Columns("O:O").ColumnWidth = 12.5

//and some colour...
aoo_excel.Range("A3:A7").Interior.Pattern = xlSolid
aoo_excel.Range("A3:A7").Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("A3:A7").Interior.Color = xColorGrey

aoo_excel.Range("C9:C12").Interior.Pattern = xlSolid
aoo_excel.Range("C9:C12").Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("C9:C12").Interior.Color = xColorGrey

aoo_excel.Range("N9:O9").Interior.Pattern = xlSolid
aoo_excel.Range("N9:O9").Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("N9:O9").Interior.Color = xColorGrey

//Add abio logo
aoo_excel.Range("A1").Select()
IF FileExists(gs_curr_dir + gs_logo_file) THEN
	aoo_excel.ActiveSheet.Shapes.AddPicture(gs_curr_dir + gs_logo_file, 	/* filename */				&
														 False,								/* LinkToFile */			&
														 True, 								/* SaveWithDocument */	&
														 5, 									/* Left*/					&
														 20, 									/* Top */					&
														 48,									/* Width */					&
														 27)									/* Height */
ELSE
	this.of_msg_db_error("Cannot find export picture " + gs_curr_dir + gs_logo_file + ' for export of ' + as_path)
END IF

ll_spreadsheet_row = 13	
FOR ll_column = 1 TO 11
	ls_total_st[ll_column] = "="
	ls_total_ot[ll_column] = "="
	ls_total_spot[ll_column] = "="
NEXT
//Now process the rows in the datastore, deleting each row once it's processed
DO &
WHILE ads_export.RowCount() > 0 &
AND ads_export.GetItemString(1, 'company') = as_book &
AND ads_export.GetItemString(1, 'job') = as_job &
AND Date(ads_export.GetItemString(1, 'job_date')) = adt_work_date &
AND ads_export.GetItemString(1, 'crew_id') = as_crew_id &
/*AND ads_export.GetItemString(1, 'scheduled') = as_scheduled*/
	ls_last_name = ads_export.GetItemString(1, 'name')
	gnv_app.inv_string.of_ParseToArray(ls_last_name, ', ', ls_names)
	aoo_excel.Range('A' + String(ll_spreadsheet_row)).Value = ls_names[1]
	aoo_excel.Range('B' + String(ll_spreadsheet_row)).Value = ads_export.GetItemString(1, 'trade')
	aoo_excel.Range('C' + String(ll_spreadsheet_row)).Value = 'ST'
	aoo_excel.Range('N' + String(ll_spreadsheet_row)).Value = '=SUM(D' + String(ll_spreadsheet_row) + ':M' + String(ll_spreadsheet_row) + ')'
	FOR ll_column = 1 TO 11
		ls_total_st[ll_column] += Char(ll_column + 67) + String(ll_spreadsheet_row) + '+'
	NEXT
	ll_spreadsheet_row ++
	
	aoo_excel.Range('A' + String(ll_spreadsheet_row)).Value = ls_names[2] 
	aoo_excel.Range('B' + String(ll_spreadsheet_row)).Value = ads_export.GetItemString(1, 'level') + ' / ' + ads_export.GetItemString(1, 'shift_cycle')
	aoo_excel.Range('C' + String(ll_spreadsheet_row)).Value = 'OT'
	aoo_excel.Range('N' + String(ll_spreadsheet_row)).Value = '=SUM(D' + String(ll_spreadsheet_row) + ':M' + String(ll_spreadsheet_row) + ')'
	FOR ll_column = 1 TO 11
		ls_total_ot[ll_column] += Char(ll_column + 67) + String(ll_spreadsheet_row) + '+'
	NEXT
	ll_spreadsheet_row ++
	
	aoo_excel.Range('A' + String(ll_spreadsheet_row)).Value = String(ads_export.GetItemNumber(1, 'emp'))
	aoo_excel.Range('B' + String(ll_spreadsheet_row)).Value = ads_export.GetItemString(1, 'shift_pattern_type')
	aoo_excel.Range('C' + String(ll_spreadsheet_row)).Value = 'SPOT'
	aoo_excel.Range('N' + String(ll_spreadsheet_row)).Value = '=SUM(D' + String(ll_spreadsheet_row) + ':M' + String(ll_spreadsheet_row) + ')'
	FOR ll_column = 1 TO 11
		ls_total_spot[ll_column] += Char(ll_column + 67) + String(ll_spreadsheet_row) + '+'
	NEXT

	aoo_excel.Range('O' + String(ll_spreadsheet_row - 2) + ':O' + String(ll_spreadsheet_row)).MergeCells = True
	
	ll_spreadsheet_row ++		
	ads_export.DeleteRow(1)
LOOP

ll_spreadsheet_row --

//Surround hours with thin borders
aoo_excel.Range("C13:N" + String(ll_spreadsheet_row)).Borders.LineStyle = xlContinuous
aoo_excel.Range("C13:N" + String(ll_spreadsheet_row)).Borders.Weight = xlThin

aoo_excel.Range("A13:C" + String(ll_spreadsheet_row)).Interior.Pattern = xlSolid
aoo_excel.Range("A13:C" + String(ll_spreadsheet_row)).Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("A13:C" + String(ll_spreadsheet_row)).Interior.Color = xColorGrey

//One medium underline for each employee
FOR ll_x = 12 TO ll_spreadsheet_row STEP 3
	aoo_excel.Range("A" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeBottom).Weight = xlMedium
	aoo_excel.Range("A" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeBottom).LineStyle = xlContinuous
	
	aoo_excel.Range("A" + String(ll_x) + ":B" + String(ll_x)).Borders(xlEdgeRight).LineStyle = xlNone
	aoo_excel.Range("A" + String(ll_x) + ":B" + String(ll_x)).Borders(xlEdgeTop).LineStyle = xlNone
	
	IF ll_x > 12 THEN
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeLeft).Weight = xlThin
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeLeft).LineStyle = xlContinuous
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlInsideVertical).Weight = xlThin
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlInsideVertical).LineStyle = xlContinuous
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeTop).Weight = xlThin
		aoo_excel.Range("C" + String(ll_x) + ":O" + String(ll_x)).Borders(xlEdgeTop).LineStyle = xlContinuous
	END IF
NEXT
	
//Surround column headings with borders
aoo_excel.Range("C9:O12").Borders.LineStyle = xlContinuous
aoo_excel.Range("C9:O11").RowHeight = 12.5
aoo_excel.Range("C12:O12").RowHeight = 60.0		//taller box for description
aoo_excel.Range("C12:O12").WrapText = TRUE		//word wrap so you can see the description

//Right justify hours labels
aoo_excel.Range("C9:C" + String(ll_x)).HorizontalAlignment = xlRight
aoo_excel.Range("B" + String(ll_x - 1) + ":B" + String(ll_x + 2)).HorizontalAlignment = xlRight

//Add the area for calculated totals
aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':C' + String(ll_spreadsheet_row + 2)).MergeCells = True
aoo_excel.Range('B' + String(ll_spreadsheet_row + 2)).Value = 'TOTAL ST'
aoo_excel.Range('B' + String(ll_spreadsheet_row + 3) + ':C' + String(ll_spreadsheet_row + 3)).MergeCells = True
aoo_excel.Range('B' + String(ll_spreadsheet_row + 3)).Value = 'OT'
aoo_excel.Range('B' + String(ll_spreadsheet_row + 4) + ':C' + String(ll_spreadsheet_row + 4)).MergeCells = True
aoo_excel.Range('B' + String(ll_spreadsheet_row + 4)).Value = 'SPOT'

aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':N' + String(ll_spreadsheet_row + 4)).Borders.LineStyle = xlContinuous
aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':N' + String(ll_spreadsheet_row + 4)).Borders.Weight = xlThin

aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':C' + String(ll_spreadsheet_row + 4)).Interior.Pattern = xlSolid
aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':C' + String(ll_spreadsheet_row + 4)).Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range('B' + String(ll_spreadsheet_row + 2) + ':C' + String(ll_spreadsheet_row + 4)).Interior.Color = xColorGrey

//Mark all the total formulas in grey, so it's clear they aren't editable
aoo_excel.Range("N13:N" + String(ll_spreadsheet_row)).Interior.Pattern = xlSolid
aoo_excel.Range("N13:N" + String(ll_spreadsheet_row)).Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("N13:N" + String(ll_spreadsheet_row)).Interior.Color = xColorGrey

aoo_excel.Range("D" + String(ll_spreadsheet_row + 2) + ":N" + String(ll_spreadsheet_row + 4)).Interior.Pattern = xlSolid
aoo_excel.Range("D" + String(ll_spreadsheet_row + 2) + ":N" + String(ll_spreadsheet_row + 4)).Interior.PatternColorIndex = xlAutomatic
aoo_excel.Range("D" + String(ll_spreadsheet_row + 2) + ":N" + String(ll_spreadsheet_row + 4)).Interior.Color = xColorGrey

//Plug in formulae for totals
FOR ll_column = 1 TO 11
	aoo_excel.Range(char(ll_column + 67) + String(ll_spreadsheet_row + 2)).Value = Left(ls_total_st[ll_column], Len(ls_total_st[ll_column]) - 1)
	aoo_excel.Range(char(ll_column + 67) + String(ll_spreadsheet_row + 3)).Value = Left(ls_total_ot[ll_column], Len(ls_total_ot[ll_column]) - 1)
	aoo_excel.Range(char(ll_column + 67) + String(ll_spreadsheet_row + 4)).Value = Left(ls_total_spot[ll_column], Len(ls_total_spot[ll_column]) - 1)
NEXT

//Left justify employee box
aoo_excel.Range("A13:A" + String(ll_spreadsheet_row + 2)).HorizontalAlignment = xlLeft

//only lock the headers, so rows are where we expect them
aoo_excel.Range("D9:M12").EntireRow.Locked = False
aoo_excel.Range("D13:M" + String(ll_spreadsheet_row)).EntireRow.Locked = False

//Protect the rest of the spreadsheet
aoo_excel.ActiveSheet.Protect("", 		/*  Password  */&
										TRUE, 	/*  DrawingObjects */ &
										TRUE, 	/*  Contents*/ &
										TRUE, 	/*  Scenarios*/ &
										TRUE , 	/*  UserInterfaceOnly */ &
										TRUE, 	/*  AllowFormattingCells*/ &
										TRUE, 	/*  AllowFormattingColumns*/ &
										TRUE, 	/*  AllowFormattingRows*/ &
										FALSE, 	/*  AllowInsertingColumns*/ &
										FALSE, 	/*  AllowInsertingRows*/ &
										FALSE, 	/*  AllowInsertingHyperlinks*/ &
										FALSE, 	/*  AllowDeletingColumns*/ &
										FALSE, 	/*  AllowDeletingRows*/ &
										FALSE, 	/*  AllowSorting*/ &
										FALSE, 	/*  AllowFiltering*/ &
										FALSE)	/*  AllowUsingPivotTables*/

//Set cursor position for when user opens file
aoo_excel.Range("B1").Select()

//Save spreadsheet
IF ab_generate_unique_filename THEN
	gnv_app.inv_string.of_ParseToArray(as_path, '.', ls_path)
	ls_filename = as_book + ' ' + String(adt_work_date, 'yyyymmdd') + ' ' + as_job + ' ' + as_crew_id 
	//ls_filename = of_trim_space(ls_filename)
	ls_filename = gnv_app.inv_string.of_GlobalReplace(ls_filename, '/', ' ')
	ls_filename = gnv_app.inv_string.of_GlobalReplace(ls_filename, '\', ' ')
	ls_filename = gnv_app.inv_string.of_GlobalReplace(ls_filename, '.', ' ')
	ls_filename = gnv_app.inv_string.of_GlobalReplace(ls_filename, '*', ' ')
	as_file_created = ls_path[1] + '\' + ls_filename + ".xlsx"
ELSE
	as_file_created = as_path
END IF
aoo_excel.ActiveWorkBook.SaveAs(as_file_created)
aoo_excel.ActiveWorkbook.close(FALSE) 
	

RETURN 1
end function

public function integer of_validate_premiums (ref n_ds ads_msg, ref hprogressbar a_hpb);//************************************************************
// Object   :	w_prcqcr 
// Function :	of_validate_premiums
// Author   :	Monica Petersen
// Date     :	2017/05/03
// 	
// Arguments:	n_ds ads_timesheets
// 				n_ds ads_msg
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


Long		ll_x
Long		ll_pt_row
Long		ll_tsp_row, ll_tsp_rows
Long		ll_tup_rows
Long		ll_ep_rows
Long		ll_msg_row
String	ls_premium_type

//Create business objects
IF Not(IsValid(ibo_premium_type)) THEN
	ibo_premium_type = CREATE n_bo_premium_type
	ibo_premium_type.of_SetTransaction()
END IF

IF Not(IsValid(ibo_timesheet_premium)) THEN
	ibo_timesheet_premium = CREATE n_bo_timesheet_premium
	ibo_timesheet_premium.of_SetTransaction()
END IF

IF Not(IsValid(ibo_employee_premium)) THEN
	ibo_employee_premium = CREATE n_bo_employee_premium
	ibo_employee_premium.of_SetTransaction()
END IF

IF Not(IsValid(ibo_trade_union_premium)) THEN
	ibo_trade_union_premium = CREATE n_bo_trade_union_premium
	ibo_trade_union_premium.of_SetTransaction()
END IF

//Process each timesheet selected
a_hpb.MinPosition = 0
a_hpb.Position = 0
a_hpb.MaxPosition = this.of_RowCount()
a_hpb.SetStep = 1
	  
FOR ll_x = 1 TO this.of_RowCount()
	a_hpb.Position = ll_x
	
	ll_tsp_rows = ibo_timesheet_premium.of_Retrieve("book = '" + this.of_GetItemString(ll_x, 'book') &
	                            				 + "' AND employee = " + String(this.of_GetItemNumber(ll_x, 'employee'))  &
	                            				 + "  AND work_date = '" + String(this.of_GetItemDateTime(ll_x, 'work_date'), 'yyyy.mm.dd')  &
	                            				 + "' AND timesheet_item = " + String(this.of_GetItemNumber(ll_x, 'timesheet_item')))
	FOR ll_tsp_row = 1 TO ll_tsp_rows
		ls_premium_type = ibo_timesheet_premium.of_GetItemString(ll_tsp_row, 'premium_type')
		ll_pt_row = ibo_premium_type.of_Find("premium_type = '" + ls_premium_type + "'")
		IF ll_pt_row > 0 THEN
			
			//Need to get the trade union premium record to validate amounts
			ll_tup_rows = ibo_trade_union_premium.of_Retrieve("book = '" + this.of_GetItemString(ll_x, 'book') &
													 + "' AND trade_union = '" + this.of_GetItemString(ll_x, 'trade_union')  &
													 + "' AND premium_type = '" + ls_premium_type &
													 + "' AND effective_date <= '" + String(this.of_GetItemDateTime(ll_x, 'work_date'), 'yyyy.mm.dd')  &
													 + "' AND expiry_date >= '" + String(this.of_GetItemDateTime(ll_x, 'work_date'), 'yyyy.mm.dd') &
													 + "'")
			IF ll_tup_rows < 1 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'employee', this.of_GetItemNumber(ll_x, 'employee'))
				ads_msg.SetItem(ll_msg_row, 'work_date', this.of_GetItemDateTime(ll_x, 'work_date'))
				ads_msg.SetItem(ll_msg_row, 'timesheet_item', this.of_GetItemNumber(ll_x, 'timesheet_item'))
				ads_msg.SetItem(ll_msg_row, 'premium_type', ls_premium_type)
				ads_msg.SetItem(ll_msg_row, 'message', 'Premium type is not effective for trade union ' + this.of_GetItemString(ll_x, 'trade_union') + " on this date." )
			ELSEIF ll_tup_rows > 1 THEN
				ll_msg_row = ads_msg.InsertRow(0)
				ads_msg.SetItem(ll_msg_row, 'employee', this.of_GetItemNumber(ll_x, 'employee'))
				ads_msg.SetItem(ll_msg_row, 'work_date', this.of_GetItemDateTime(ll_x, 'work_date'))
				ads_msg.SetItem(ll_msg_row, 'timesheet_item', this.of_GetItemNumber(ll_x, 'timesheet_item'))
				ads_msg.SetItem(ll_msg_row, 'premium_type', ls_premium_type)
				ads_msg.SetItem(ll_msg_row, 'message', 'Premium type is defined multiple times for trade union ' + this.of_GetItemString(ll_x, 'trade_union') )
			ELSE			
				IF ibo_premium_type.of_GetItemString(ll_pt_row, 'employee_specific_flag') = 'Y' THEN
					//Verify premium is defined on employee record
					ll_ep_rows = ibo_employee_premium.of_Retrieve("book = '" + this.of_GetItemString(ll_x, 'book') &
															 + "' AND employee = " + String(this.of_GetItemNumber(ll_x, 'employee'))  &
													 		 + "  AND premium_type = '" + ls_premium_type &
															 + "' AND effective_date <= '" + String(this.of_GetItemDateTime(ll_x, 'work_date'), 'yyyy.mm.dd')  &
															 + "' AND expiry_date >= '" + String(this.of_GetItemDateTime(ll_x, 'work_date'), 'yyyy.mm.dd') &
															 + "'")
					IF ll_ep_rows <> 1 THEN
						ll_msg_row = ads_msg.InsertRow(0)
						ads_msg.SetItem(ll_msg_row, 'employee', this.of_GetItemNumber(ll_x, 'employee'))
						ads_msg.SetItem(ll_msg_row, 'work_date', this.of_GetItemDateTime(ll_x, 'work_date'))
						ads_msg.SetItem(ll_msg_row, 'timesheet_item', this.of_GetItemNumber(ll_x, 'timesheet_item'))
						ads_msg.SetItem(ll_msg_row, 'premium_type', ls_premium_type)
						ads_msg.SetItem(ll_msg_row, 'message', 'Employee premium is not effective on this date.')
					ELSEIF ll_ep_rows = 1 THEN
						//Verify rate matches rate on employee premium
						IF ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate') <> ibo_employee_premium.of_GetItemDecimal(1, 'reg_rate') &
						OR ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_rate') <> ibo_employee_premium.of_GetItemDecimal(1, 'tah_rate') &
						OR ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_rate') <> ibo_employee_premium.of_GetItemDecimal(1, 'ovr_rate') THEN
							ll_msg_row = ads_msg.InsertRow(0)
							ads_msg.SetItem(ll_msg_row, 'employee', this.of_GetItemNumber(ll_x, 'employee'))
							ads_msg.SetItem(ll_msg_row, 'work_date', this.of_GetItemDateTime(ll_x, 'work_date'))
							ads_msg.SetItem(ll_msg_row, 'timesheet_item', this.of_GetItemNumber(ll_x, 'timesheet_item'))
							ads_msg.SetItem(ll_msg_row, 'premium_type', ls_premium_type)
							ads_msg.SetItem(ll_msg_row, 'message', "Timesheet premium rates (" &
									+ String(ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'), "0.00") + "/"  &
									+ String(ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'tah_rate'), "0.00") + "/"  &
									+ String(ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'ovr_rate'), "0.00")  &
									+ ") don't match premium rates defined for employee " + String(this.of_GetItemNumber(ll_x, 'employee')) &
									+ " (" &
									+ String(ibo_employee_premium.of_GetItemDecimal(1, 'reg_rate'), "0.00") + "/"  &
									+ String(ibo_employee_premium.of_GetItemDecimal(1, 'tah_rate'), "0.00") + "/"  &
									+ String(ibo_employee_premium.of_GetItemDecimal(1, 'ovr_rate'), "0.00") + ")")
						END IF
					END IF
				END IF
				
				//Verify rate is within the range defined on the trade union
				IF (ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate') < ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate') &
				    OR ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate') > ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate')) &
				AND ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_2_flag') = 'N' &
				AND ibo_premium_type.of_GetItemString(ll_pt_row, 'shift_3_flag') = 'N' THEN
					ll_msg_row = ads_msg.InsertRow(0)
					ads_msg.SetItem(ll_msg_row, 'employee', this.of_GetItemNumber(ll_x, 'employee'))
					ads_msg.SetItem(ll_msg_row, 'work_date', this.of_GetItemDateTime(ll_x, 'work_date'))
					ads_msg.SetItem(ll_msg_row, 'timesheet_item', this.of_GetItemNumber(ll_x, 'timesheet_item'))
					ads_msg.SetItem(ll_msg_row, 'premium_type', ls_premium_type)
					ads_msg.SetItem(ll_msg_row, 'message', 'Rate (' &
									+ String(ibo_timesheet_premium.of_GetItemDecimal(ll_tsp_row, 'reg_rate'), "0.00")  &
									+ ') is outside the range for trade union ' + this.of_GetItemString(ll_x, 'trade_union') &
									+ " (" &
									+ String(ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate'), "0.00") + " to "  &
									+ String(ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate'), "0.00") + ")" )
				END IF
					
			END IF
		END IF
	NEXT
		
NEXT

RETURN 1

end function

public function datetime of_convert_date (string as_date);//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_convert_date
// Author   :	Monica Petersen
// Date     :	2017/11/24
// 	
// Arguments:	string as_date
// 	
// Returns:		datetime
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

String	ls_work, ls_date[], ls_empty[], ls_day, ls_month, ls_year
Integer	li_row
DateTime	ldt_work
Date		ld_work

ld_work = Date(as_date)
IF ld_work = Date(1900,1,1) THEN
	ls_work = as_date
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, ' 00:00:00', '')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '.', ' ')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '-', ' ')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '_', ' ')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '/', ' ')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '\', ' ')
	ls_work = gnv_app.inv_string.of_GlobalReplace(ls_work, '\', ' ')
	ls_work = gnv_app.inv_string.of_Trim_Space(ls_work)
	ls_date = ls_empty
	ls_day = ''
	ls_month = ''
	ls_year = ''
	gnv_app.inv_string.of_ParseToArray(ls_work, ' ', ls_date)
	FOR li_row = 1 TO UpperBound(ls_date)
		IF IsNumber(ls_date[li_row]) THEN
			IF Len(ls_date[li_row]) = 4 THEN
				ls_year = ls_date[li_row]
			ELSE
				ls_day = ls_date[li_row]
			END IF
		ELSE
			IF Pos('JANFEBMARAPRMAYJUNJULAUGSEPTOCTNOVDEC',Upper(ls_date[li_row])) > 0 THEN
				ls_month = ls_date[li_row]
			ELSEIF Pos('JANUARYFEBRUARYMARCHAPRILMAYJUNEJULYAUGUSTSEPTEMBEROCTOBERNOVEMBERDECEMBER',Upper(ls_date[li_row])) > 0 THEN
				ls_month = ls_date[li_row]
			END IF
		END IF
	NEXT
	
	IF ls_day <> '' AND ls_month <> '' AND ls_year <> '' THEN
		ldt_work = DateTime(Date(Integer(ls_year), gnv_app.inv_datetime.of_MonthNumber(ls_month), Integer(ls_day)), Time(0,0,0))
	ELSE
		gnv_app.inv_string.of_GlobalReplace(ls_work, ' ', '.')
		ldt_work = DateTime(Date(ls_work), Time(0,0,0))
	END IF
ELSE
	ldt_work = DateTime(ld_work, Time(0,0,0))
END IF

RETURN ldt_work
end function

public function integer of_insert_issl_timesheets (string as_file, ref string as_memo, ref datetime adt_work_from, ref datetime adt_work_to, ref n_bo_timesheet_premium abo_timesheet_premium);//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_insert_ISSL_timesheets
// Author   :	Monica Petersen
// Date     :	2017/11/21
// 	
// Arguments:	string as_file
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

Long			ll_page, ll_employee, ll_job, ll_job_row, ll_ts_row, ll_employee_row, ll_item, ll_e_row, ll_rows, ll_tab
Integer		li_row, li_rc, li_err

Decimal		ldec_reg, ldec_tah, ldec_ovr, ldec_taxi, ldec_loa, ldec_prem_reg_rate, ldec_prem_tah_rate, ldec_prem_ovr_rate
String		ls_col, ls_shift = '1', ls_jc_labour_cost, ls_company_pr_yyyymm, ls_company_wcb_class, ls_company_gst_rule
String		ls_null, ls_dirs[], ls_file_name, ls_job, ls_centre[], ls_empty[], ls_date[], ls_work, ls_day, ls_month, ls_year
String		ls_name_1, ls_name_2 
String		ls_job_description, ls_comments
Any 			la_value
DateTime		ldt_work
Boolean	lb_asked_and_answered = FALSE, lb_employee_found, lb_1, lb_2, lb_3, lb_4, lb_5
OLEObject 	loo_excel
n_bo_job			lbo_job
n_bo_employee	lbo_employee
n_bo_standard_control_account	lbo_standard_control_account
n_bo_occupation_rate	lbo_occupation_rate
n_bo_occupation		lbo_occupation
n_bo_area				lbo_area
n_bo_timesheet			lbo_timesheet_temp
n_bo_trade_union_rate		lbo_trade_union_rate

s_parm	lstr_parm
n_ds		lds_popup
s_parm	lstr_dummy
s_validation_error			s_error[]

SetNull(ls_null)

IF FileExists(as_file) THEN 
		
	loo_excel = CREATE OLEObject 
	IF loo_excel.ConnectToNewObject( "excel.application" ) <> 0 THEN
		MessageBox('Timesheet Import', "Cannot connect to MS Excel. Please make sure it is installed.", Exclamation!) 
		loo_excel.ActiveWorkbook.close(FALSE) 
		DESTROY loo_excel
		RETURN -1
	END IF
	loo_excel.visible = FALSE
	
	lds_popup = create n_ds
	lds_popup.dataobject = 'd_popup_employees_named'
	IF lds_popup.of_SetTransObject(sqlca) = -1 THEN
		this.of_msg_db_error("Error setting up search list")
		loo_excel.ActiveWorkbook.close(FALSE) 
		DESTROY loo_excel
		RETURN -1
	END IF

	//Save filename for memo field reference
	gnv_app.inv_string.of_ParseToArray(as_file, '\', ls_dirs)
	ls_file_name = ls_dirs[UpperBound(ls_dirs)]
	as_memo = ls_file_name // use this to list timesheets

	lbo_occupation_rate = CREATE n_bo_occupation_rate
	lbo_occupation_rate.of_SetTransaction()

	lbo_occupation = CREATE n_bo_occupation
	lbo_occupation.of_SetTransaction()

	lbo_area = CREATE n_bo_area
	lbo_area.of_SetTransaction()

	lbo_timesheet_temp = CREATE n_bo_timesheet
	lbo_timesheet_temp.of_SetTransaction()

	lbo_trade_union_rate = CREATE n_bo_trade_union_rate
	lbo_trade_union_rate.of_SetTransaction()

	/* gst_rule is now from application_properties */
	select pr_yyyymm,
			 wcb_class
	  into :ls_company_pr_yyyymm,
			 :ls_company_wcb_class
	  from company 
	 WHERE book 		= :gnv_app.is_book
	 using sqlca;
	IF sqlca.sqlcode <> 0 THEN
		this.of_msg_db_error("ERROR retrieving defaults", sqlca)
		loo_excel.ActiveWorkbook.close(FALSE) 
		DESTROY loo_excel
		RETURN -1
	END IF
	
	/* get gst_rule from application_properties */
	select gst_rule
	  into :ls_company_gst_rule
	  from application_properties
	 using sqlca;
	IF sqlca.sqlcode <> 0 THEN
		this.of_msg_db_error("ERROR retrieving defaults", sqlca)
		loo_excel.ActiveWorkbook.close(FALSE) 
		DESTROY loo_excel
		RETURN -1
	END IF

	//Use business object to retrieve control accounts
	lbo_standard_control_account = CREATE n_bo_standard_control_account
	lbo_standard_control_account.of_SetTransaction(sqlca)
	IF lbo_standard_control_account.of_Retrieve('') < 1 THEN
		this.of_msg_db_error("Error reading control account", sqlca)
		loo_excel.ActiveWorkbook.close(FALSE) 
		DESTROY loo_excel
		RETURN -1
	END IF
	ls_jc_labour_cost = lbo_standard_control_account.of_GetItemString(1, 'jc_lab_cost')
	DESTROY lbo_standard_control_account

	lbo_employee = CREATE n_bo_employee
	lbo_employee.of_SetTransaction()
	
	lbo_job = CREATE n_bo_job
	lbo_job.of_SetTransaction()
	
	loo_excel.workbooks.open(as_file,TRUE,TRUE) //open as read only 
	
	FOR ll_tab = 1 TO 2
				
		IF ll_tab = 1 THEN
			
			loo_excel.Worksheets(1).Activate
			IF Upper(loo_excel.ActiveWorkBook.ActiveSheet.Name) = "DAYS" THEN
				ls_shift = '1'
			ELSE
				CONTINUE
			END IF
			
		ELSE
			IF loo_excel.ActiveWorkBook.WorkSheets.Count > 1 THEN
				loo_excel.WorkSheets(2).Activate
				IF Upper(loo_excel.ActiveWorkBook.ActiveSheet.Name) = "NIGHTS" THEN
					ls_shift = '2'
				ELSE
					//Skip the second sheet, it isn't there.
					CONTINUE
				END IF
			ELSE
				CONTINUE
			END IF
		END IF
		
		//Process 20 pages with 5 employees on each page, the first page only having 4
		//because of the totals line
		FOR ll_page = 1 TO 20
			
			// work date
			la_value = loo_excel.Range('X' + String(((ll_page - 1) * 28) + 1)).Value
			ldt_work = of_convert_date(String(la_value))
		
			//Jobs are on page 1, row 3, page 2 row 31 , page 3 row 59, page 4 row 87
			ll_job_row = ((ll_page - 1) * 28) + 3
	
			FOR ll_e_row = 1 TO 5
				
				IF ll_page = 1 AND ll_e_row = 1 THEN
					//totals, skip this
				ELSE
					
					//Get employee number - it might move around, but it's import so look in every cell for a number
					ll_employee_row = ll_job_row + ((ll_e_row - 1) * 5) 
					la_value = loo_excel.Range('B' + String(ll_employee_row + 4)).Value
					ll_employee = Long(la_value)
					IF IsNull(ll_employee) OR ll_employee = 0 THEN 
						la_value = loo_excel.Range('A' + String(ll_employee_row + 5)).Value
						ll_employee = Long(la_value)
						IF IsNull(ll_employee) OR ll_employee = 0 THEN 
							la_value = loo_excel.Range('A' + String(ll_employee_row + 1)).Value
							ll_employee = Long(la_value)
							IF IsNull(ll_employee) OR ll_employee = 0 THEN 
								la_value = loo_excel.Range('A' + String(ll_employee_row + 2)).Value
								ll_employee = Long(la_value)
								IF IsNull(ll_employee) OR ll_employee = 0 THEN 
									la_value = loo_excel.Range('A' + String(ll_employee_row + 3)).Value
									ll_employee = Long(la_value)
									IF IsNull(ll_employee) OR ll_employee = 0 THEN 
										la_value = loo_excel.Range('A' + String(ll_employee_row + 4)).Value
										ll_employee = Long(la_value)
										IF IsNull(ll_employee) OR ll_employee = 0 THEN 
											la_value = loo_excel.Range('B' + String(ll_employee_row + 1)).Value
											ll_employee = Long(la_value)
											IF IsNull(ll_employee) OR ll_employee = 0 THEN 
												la_value = loo_excel.Range('B' + String(ll_employee_row + 2)).Value
												ll_employee = Long(la_value)
												IF IsNull(ll_employee) OR ll_employee = 0 THEN 
													la_value = loo_excel.Range('B' + String(ll_employee_row + 3)).Value
													ll_employee = Long(la_value)
													IF IsNull(ll_employee) OR ll_employee = 0 THEN 
														la_value = loo_excel.Range('B' + String(ll_employee_row + 5)).Value
														ll_employee = Long(la_value)
														IF IsNull(ll_employee) THEN 
															ll_employee = 0
														END IF
													END IF
												END IF
											END IF
										END IF
									END IF
								END IF
							END IF
						END IF
					END IF
						
					//Get employee name
					ls_name_1 = ''
					ls_name_2 = ''
					la_value = loo_excel.Range('A' + String(ll_employee_row + 1)).Value
					IF Not(IsNull(la_value) OR Trim(String( la_value )) = '') THEN
						ls_name_1 = String(la_value)
					END IF
					
					la_value = loo_excel.Range('A' + String(ll_employee_row + 2)).Value
					IF Not(IsNull(la_value) OR Trim(String( la_value )) = '') THEN
						IF ls_name_1 = ''THEN
							ls_name_1 = String(la_value)
						ELSE
							ls_name_2 = String(la_value)
						END IF
					END IF
					
					la_value = loo_excel.Range('A' + String(ll_employee_row + 3)).Value
					IF Not(IsNull(la_value) OR Trim(String( la_value )) = '') THEN
						IF ls_name_1 = ''THEN
							ls_name_1 = String(la_value)
						ELSEIF ls_name_2 = '' THEN
							ls_name_2 = String(la_value)
						END IF
					END IF
					
					la_value = loo_excel.Range('A' + String(ll_employee_row + 4)).Value
					IF Not(IsNull(la_value) OR Trim(String( la_value )) = '') THEN
						IF ls_name_1 = ''THEN
							ls_name_1 = String(la_value)
						ELSEIF ls_name_2 = '' THEN
							ls_name_2 = String(la_value)
						END IF
					END IF
					
					la_value = loo_excel.Range('A' + String(ll_employee_row + 5)).Value
					IF Not(IsNull(la_value) OR Trim(String( la_value )) = '') THEN
						IF ls_name_1 = ''THEN
							ls_name_1 = String(la_value)
						ELSEIF ls_name_2 = '' THEN
							ls_name_2 = String(la_value)
						END IF
					END IF
					
					lb_employee_found = FALSE
					IF ll_employee <> 0 THEN
						IF lbo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' and employee = " + String(ll_employee)) = 1 THEN
							IF  Pos(Upper(lbo_employee.of_GetItemString(1, 'name')), Upper(ls_name_1)) > 0 &
							AND Pos(Upper(lbo_employee.of_GetItemString(1, 'name')), Upper(ls_name_2)) > 0 THEN
								lb_employee_found = TRUE
							END IF
						END IF
					END IF
					
					IF Not(lb_employee_found) THEN
						//Ensure employee number matches employee name
						IF Len(ls_name_1 + ls_name_2) > 0 THEN
							
							//Need to lookup employee in person table
							ll_rows = lds_popup.Retrieve(gnv_app.of_get_book(), ll_employee, ls_name_1, ls_name_2, 0.95) 
							IF ll_rows < 1 THEN
								MessageBox("Search Employee","There are no employees named " + ls_name_1 + ' ' + ls_name_2 + " currently in the system.  Please add the employee and retry the import.")
								loo_excel.ActiveWorkbook.close(FALSE) 
								DESTROY loo_excel
								RETURN -1
							ELSE
								//Most likely name doesn't match number, ask user to verify employee number
								lstr_parm.s_parm[1] = 'Select Employee Number for '  + ls_name_1 + ' ' + ls_name_2 + ' (recorded in import as ' + String(ll_employee) + ')'
								lstr_parm.po_parm[1] = lds_popup
								
								OpenWithParm(w_pr_timesheet_employee, lstr_parm)
								
								ll_employee = Message.DoubleParm
								IF IsNull(ll_employee) OR ll_employee = 0 THEN
									MessageBox('Import Timesheets','Cannot determine employee number for ' + ls_name_1 + ' ' + ls_name_2 + ".  Import cancelled.")
									loo_excel.ActiveWorkbook.close(FALSE) 
									DESTROY loo_excel
									RETURN -1
								END IF															
							END IF
						
						ELSE
							//No name or number supplied, exit the employee FOR loop
							CONTINUE
						END IF
					END IF
					
					//Employee data
					IF lbo_employee.of_Retrieve("book = '" + gnv_app.is_book + "' and employee = " + String(ll_employee)) = 1 THEN
													
						//Capture any comments
						ls_comments = ''
						la_value = loo_excel.Range('X' + String(ll_employee_row + 1)).Value
						IF Not(IsNull(la_value)) THEN ls_comments += 'cell X' + String(ll_employee_row + 1) + ': ' + Trim(String(la_value)) + ' '
						la_value = loo_excel.Range('X' + String(ll_employee_row + 2)).Value
						IF Not(IsNull(la_value)) THEN ls_comments += 'cell X' + String(ll_employee_row + 2) + ': ' + Trim(String(la_value)) + ' '
						la_value = loo_excel.Range('X' + String(ll_employee_row + 3)).Value
						IF Not(IsNull(la_value)) THEN ls_comments += 'cell X' + String(ll_employee_row + 3) + ': ' + Trim(String(la_value)) + ' '
						la_value = loo_excel.Range('X' + String(ll_employee_row + 4)).Value
						IF Not(IsNull(la_value)) THEN ls_comments += 'cell X' + String(ll_employee_row + 4) + ': ' + Trim(String(la_value)) + ' '
						la_value = loo_excel.Range('X' + String(ll_employee_row + 5)).Value
						IF Not(IsNull(la_value)) THEN ls_comments += 'cell X' + String(ll_employee_row + 5) + ': ' + Trim(String(la_value)) + ' '
						
						//10 Jobs are across the top of the page
						FOR ll_job = 1 TO 10
							CHOOSE CASE ll_job
								CASE 1
									ls_col = 'D'
								CASE 2
									ls_col = 'E'
								CASE 3
									ls_col = 'F'
								CASE 4
									ls_col = 'G'
								CASE 5
									ls_col = 'H'
								CASE 6
									ls_col = 'I'
								CASE 7
									ls_col = 'J'
								CASE 8
									ls_col = 'K'
								CASE 9
									ls_col = 'L'
								CASE 10
									ls_col = 'M'
							END CHOOSE
							
							//Get job
							ls_centre = ls_empty
							la_value = loo_excel.Range(ls_col + String(ll_job_row)).Value
							IF Not(IsNull(la_value)) AND String(la_value) <> '0' THEN					
								//Job may have area appended
								ls_job = String(la_value)
								gnv_app.inv_string.of_ParseToArray(ls_job, '-', ls_centre)
							ELSE
								SetNull(ls_job)
								ls_centre[1] = ls_job
							END IF
							
							//Get job description
							la_value = loo_excel.Range(ls_col + String(ll_job_row - 1)).Value
							IF Not(IsNull(la_value)) THEN					
								ls_job_description = 'cell ' + ls_col + String(ll_job_row - 1) + ': ' + String(la_value) + ' '
							ELSE
								ls_job_description = ''
							END IF
															
							//Regular time
							la_value = loo_excel.Range(ls_col + String(ll_employee_row + 1)).Value
							IF Not(IsNull(la_value)) THEN
								ldec_reg = Dec(la_value)
							ELSE
								ldec_reg = 0
							END IF
							
							//Time and a half
							la_value = loo_excel.Range(ls_col + String(ll_employee_row + 2)).Value
							IF Not(IsNull(la_value)) THEN
								ldec_tah = Dec(la_value)
							ELSE
								ldec_tah = 0
							END IF
							
							//Overtime
							la_value = loo_excel.Range(ls_col + String(ll_employee_row + 3)).Value
							IF Not(IsNull(la_value)) THEN
								ldec_ovr = Dec(la_value)
							ELSE
								ldec_ovr = 0
							END IF
							
							//Taxi
							la_value = loo_excel.Range(ls_col + String(ll_employee_row + 4)).Value
							IF Not(IsNull(la_value)) THEN
								ldec_taxi = Dec(la_value)
							ELSE
								ldec_taxi = 0
							END IF
							
							//LOA
							la_value = loo_excel.Range(ls_col + String(ll_employee_row + 5)).Value
							IF Not(IsNull(la_value)) THEN
								ldec_LOA = Dec(la_value)
							ELSE
								ldec_LOA = 0
							END IF
							
							IF ldec_reg <> 0 &
							OR ldec_tah <> 0 &
							OR ldec_ovr <> 0 &
							OR ldec_taxi <> 0 &
							OR ldec_LOA <> 0 THEN
							
								//Pass back date that was associated with hours
								IF ldt_work < adt_work_from OR this.of_RowCount() = 0 THEN adt_work_from = ldt_work						
								IF ldt_work > adt_work_to OR this.of_RowCount() = 0 THEN adt_work_to = ldt_work
								
								//Find the next timesheet item, either from this file...
								this.of_SetFilter("employee = " + String(ll_employee) + " AND work_date = Date('" + String(ldt_work, 'yyyy.mm.dd') + "')")
								this.of_Filter()
								IF this.of_RowCount() > 0 THEN
									this.of_SetSort("work_date DESC, timesheet_item DESC")
									this.of_Sort()
									ll_item = this.of_GetItemNumber(1, 'timesheet_item') + 1
								ELSE
									//... or from the database
									ll_item = this.of_get_next_ts_item(ll_employee, ldt_work)
									IF ll_item > 1 THEN
										IF Not(lb_asked_and_answered) THEN
											IF MessageBox('Import Timesheets', "A timesheet already exists for " + String(ll_employee) + " on " + String(ldt_work, 'yyyy.mm.dd') + ". Continue import?", Exclamation!, YesNo!, 2) = 2 THEN
												loo_excel.ActiveWorkbook.close(FALSE) 
												DESTROY loo_excel
												RETURN -1
											END IF
										END IF
										lb_asked_and_answered = TRUE
									END IF
								END IF
									
								ll_ts_row = this.of_InsertRow(0)
								this.of_SetItem(ll_ts_row, 'book', gnv_app.is_book)
								this.of_SetItem(ll_ts_row, 'work_date', ldt_work)
								this.of_SetItem(ll_ts_row, 'employee', ll_employee)
								this.of_SetItem(ll_ts_row, 'timesheet_item', ll_item)
								this.of_SetItem(ll_ts_row, 'memo', 'Imported from: ' + ls_file_name + ', cell A' + String(ll_employee_row + 2))
								
								//Add any comments or job description to memo
								ls_job_description = Trim(ls_job_description)
								ls_comments = Trim(ls_comments)
								IF Len(ls_job_description) > 0 OR Len(ls_comments) > 0 THEN
									this.of_SetItem(ll_ts_row, 'memo', Trim(this.of_GetItemString(ll_ts_row, 'memo')) + ' (' )
									
									IF Len(ls_job_description) > 0 THEN 
										this.of_SetItem(ll_ts_row, 'memo', this.of_GetItemString(ll_ts_row, 'memo')  + ls_job_description )
										IF Len(ls_comments) > 0 THEN 
											this.of_SetItem(ll_ts_row, 'memo', this.of_GetItemString(ll_ts_row, 'memo')  + ', ')
										END IF
									END IF
									
									IF Len(ls_comments) > 0 THEN 
										this.of_SetItem(ll_ts_row, 'memo', this.of_GetItemString(ll_ts_row, 'memo')  + ls_comments)
									END IF
									
									this.of_SetItem(ll_ts_row, 'memo', Trim(this.of_GetItemString(ll_ts_row, 'memo'))  + ')')
								END IF	
								
								this.of_SetItem(ll_ts_row, 'job', ls_centre[1])
								IF UpperBound(ls_centre) > 1 THEN
									this.of_SetItem(ll_ts_row, 'area', ls_centre[2])
								ELSEIF Not(IsNull(ls_centre[1])) THEN
									//Get first area for the job
									lbo_area.of_min('area', "book = '" + gnv_app.is_book + "' AND job = '" + ls_centre[1] + "'", ls_centre[2])
									this.of_SetItem(ll_ts_row, 'area', ls_centre[2])
								END IF
									
								this.of_SetItem(ll_ts_row, 'reg_hour', ldec_reg)
								this.of_SetItem(ll_ts_row, 'tah_hour', ldec_tah)
								this.of_SetItem(ll_ts_row, 'ovr_hour', ldec_ovr)
								this.of_SetItem(ll_ts_row, 'taxi', 		ldec_taxi)
								this.of_SetItem(ll_ts_row, 'loa', 		ldec_LOA)
								
								//WCB class from job
								IF Len(this.of_GetItemString(ll_ts_row, 'job')) > 0  THEN
									IF lbo_job.of_Retrieve("book = '" + gnv_app.is_book + "' and job = '" + this.of_GetItemString(ll_ts_row, 'job') + "'") = 1 THEN
										IF lbo_employee.of_GetItemString(1, 'job_based_wcb_class') = 'Y' THEN
											this.of_SetItem(ll_ts_row, 'wcb_class', lbo_job.of_GetItemString(1, "wcb_class"))
										ELSEIF Len(lbo_employee.of_GetItemString(1, "wcb_class")) > 0 THEN
											this.of_SetItem(ll_ts_row, 'wcb_class', lbo_employee.of_GetItemString(1, "wcb_class"))
										ELSE
											this.of_SetItem(ll_ts_row, 'wcb_class', ls_company_wcb_class)
										END IF
									ELSE
										this.of_SetItem(ll_ts_row, 'wcb_class', ls_company_wcb_class)
									END IF
								ELSE
									this.of_SetItem(ll_ts_row, 'wcb_class', ls_company_wcb_class)
								END IF
				
								//company defaults
								this.of_SetItem(ll_ts_row, 'gl_account', 	ls_jc_labour_cost)
								this.of_SetItem(ll_ts_row, 'pr_yyyymm', 	ls_company_pr_yyyymm)
								this.of_SetItem(ll_ts_row, 'gst_rule', 	ls_company_gst_rule)
								this.of_SetItem(ll_ts_row, 'timesheet_status', 'W')
								this.of_SetItem(ll_ts_row, 'file_type', 'P')

								this.of_SetItem(ll_ts_row, 'trade_union', 		lbo_employee.of_GetItemString(1, "trade_union"))
								//this.of_SetItem(ll_ts_row, 'occupation', 			lbo_employee.of_GetItemString(1, "occupation"))
								this.of_SetItem(ll_ts_row, 'shift', 				ls_shift)
								this.of_SetItem(ll_ts_row, 'employment_type', 	lbo_employee.of_GetItemString(1, "employment_type"))
								this.of_SetItem(ll_ts_row, 'loa_rate', 			lbo_employee.of_GetItemDecimal(1, "loa_rate"))
								this.of_SetItem(ll_ts_row, 'mileage_rate', 		lbo_employee.of_GetItemDecimal(1, "mileage_rate"))
						
								//occupation
								la_value = loo_excel.Range('B' + String(ll_employee_row + 2)).Value
								IF Not(IsNull(la_value)) THEN
									this.of_SetItem(ll_ts_row, 'occupation', Upper(String(la_value)))
								ELSE
									//User *might* have put the occupation in the first row
									la_value = loo_excel.Range('B' + String(ll_employee_row + 1)).Value
									IF Not(IsNull(la_value)) THEN
										this.of_SetItem(ll_ts_row, 'occupation', Upper(String(la_value)))
									ELSE
										//Well, they might have put it anywhere in the 'TRADE' column really
										la_value = loo_excel.Range('B' + String(ll_employee_row + 3)).Value
										IF Not(IsNull(la_value)) THEN
											this.of_SetItem(ll_ts_row, 'occupation', Upper(String(la_value)))
										ELSE
											la_value = loo_excel.Range('B' + String(ll_employee_row + 4)).Value
											IF Not(IsNull(la_value)) THEN
												this.of_SetItem(ll_ts_row, 'occupation', Upper(String(la_value)))
											ELSE
												la_value = loo_excel.Range('B' + String(ll_employee_row + 5)).Value
												IF Not(IsNull(la_value)) THEN
													this.of_SetItem(ll_ts_row, 'occupation', Upper(String(la_value)))
												END IF
											END IF
										END IF
									END IF
								END IF
								
								//Now have enough information to generate premiums
								ldec_prem_reg_rate = 0
								ldec_prem_tah_rate = 0
								ldec_prem_ovr_rate = 0
							
								abo_timesheet_premium.of_generate_timesheet_premiums(gnv_app.is_book, 													&
																									  this.of_GetItemNumber(ll_ts_row, 'employee'), 			&
																									  this.of_GetItemDateTime(ll_ts_row, 'work_date'), 		&
																									  this.of_GetItemNumber(ll_ts_row, 'timesheet_item'), 	&
																									  this.of_GetItemString(ll_ts_row, 'trade_union'), 		&
																									  this.of_GetItemString(ll_ts_row, "occupation"), 			&
																									  this.of_GetItemString(ll_ts_row, 'shift'),				&
																									  FALSE,									&
																									  lstr_dummy, &
																					  				  ldec_reg, ldec_tah, ldec_ovr, &
																									  ldec_prem_reg_rate, ldec_prem_tah_rate, ldec_prem_ovr_rate)
																										 
								IF lbo_trade_union_rate.of_Retrieve("book = '" + gnv_app.is_book &
										+ "' AND trade_union = '" + this.of_GetItemString(ll_ts_row, 'trade_union') &
										+ "' AND '" + String(ldt_work, 'YYYYMMDD') + "' BETWEEN CONVERT(varchar, effective_date, 112) AND CONVERT(varchar, expiry_date, 112)") < 1 THEN
									MessageBox("Timesheet Import", "Union rates are not available for trade union " + this.of_GetItemString(ll_ts_row, 'trade_union') + " on " + String(ldt_work, 'yyyy.mm.dd') + ".")  // jira 2371 just return, we'll catch the problem later
									loo_excel.ActiveWorkbook.close(FALSE) 
									DESTROY loo_excel
									RETURN 0
								END IF

								//Get the rates for this employee/trade union/occupation
								IF lbo_occupation_rate.of_current_occupation_rate(gnv_app.is_book, &
																								  this.of_GetItemString(ll_ts_row, 'trade_union'), &
																								  this.of_GetItemString(ll_ts_row, 'occupation'), &
																								  this.of_GetItemDateTime(ll_ts_row, 'work_date')) THEN
									this.of_SetItem(ll_ts_row, 'base_rate', 	lbo_occupation_rate.of_GetItemDecimal(1, "base_rate"))
									this.of_SetItem(ll_ts_row, 'reg_rate', 	lbo_occupation_rate.of_GetItemDecimal(1, "reg_rate") + ldec_prem_reg_rate)
									this.of_SetItem(ll_ts_row, 'tah_rate', 	lbo_occupation_rate.of_GetItemDecimal(1, "tah_rate") + ldec_prem_tah_rate)
									this.of_SetItem(ll_ts_row, 'ovr_rate', 	lbo_occupation_rate.of_GetItemDecimal(1, "ovr_rate") + ldec_prem_ovr_rate)
									this.of_SetItem(ll_ts_row, 'travel_rate',	lbo_occupation_rate.of_GetItemDecimal(1, "base_rate") )
									IF lbo_trade_union_rate.of_GetItemString(1, 'include_travel_flag') = 'Y' THEN 
										this.of_SetItem(ll_ts_row, 'travel_rate', this.of_GetItemDecimal(ll_ts_row, 'travel_rate') + ldec_prem_reg_rate)
									END IF
									this.of_SetItem(ll_ts_row, 'reg_earn', 	Round(this.of_GetItemDecimal(ll_ts_row, 'reg_hour') 	* this.of_GetItemDecimal(ll_ts_row, 'reg_rate'), 2))
									this.of_SetItem(ll_ts_row, 'tah_earn', 	Round(this.of_GetItemDecimal(ll_ts_row, 'tah_hour') 	* this.of_GetItemDecimal(ll_ts_row, 'tah_rate'), 2))
									this.of_SetItem(ll_ts_row, 'ovr_earn', 	Round(this.of_GetItemDecimal(ll_ts_row, 'ovr_hour') 	* this.of_GetItemDecimal(ll_ts_row, 'ovr_rate'), 2))
									this.of_SetItem(ll_ts_row, 'total', 		this.of_GetItemDecimal(ll_ts_row, 'reg_earn') 					&
																						 + this.of_GetItemDecimal(ll_ts_row, 'tah_earn') 					&
																						 + this.of_GetItemDecimal(ll_ts_row, 'ovr_earn') 					&
																						 + this.of_GetItemDecimal(ll_ts_row, 'taxi') 						&
																						 + this.of_GetItemDecimal(ll_ts_row, 'LOA'))
									
									//Determine centre
									IF UpperBound(ls_centre) > 2 THEN
										//job was specified as job-area-centre
										this.of_SetItem(ll_ts_row, 'centre', ls_centre[3])
									ELSEIF lbo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
												+ "' AND trade_union = '" + this.of_GetItemString(ll_ts_row, 'trade_union')  &
												+ "' AND occupation = '" + this.of_GetItemString(ll_ts_row, 'occupation') + "'") = 1 THEN
										//use the default for this occupation
										this.of_SetItem(ll_ts_row, 'centre', lbo_occupation.of_GetItemString(1, 'centre'))
									END IF
								ELSEIF Len(this.of_GetItemString(ll_ts_row, 'occupation')) > 0 THEN									
									this.of_SetItem(ll_ts_row, 'memo', this.of_GetItemString(ll_ts_row, 'memo') + ' occ: ' + this.of_GetItemString(ll_ts_row, 'occupation'))
									this.of_SetItem(ll_ts_row, 'occupation', ls_null)
								END IF

								this.of_SetItem(ll_ts_row, 'memo', Left(this.of_GetItemString(ll_ts_row, 'memo'), 100))
								
								//Have we a successful import?  If so, the file type can be set to 'C'urrent instead of 'P'reliminary
								lbo_timesheet_temp.of_Reset()
								li_rc = This.ids_data.RowsCopy(ll_ts_row, ll_ts_row, Primary!, lbo_timesheet_temp.ids_data, 1, Primary!)
								IF lbo_timesheet_temp.of_Validate() = 1 THEN
									this.of_SetItem(ll_ts_row, 'file_type', 'C')
								ELSE
									lbo_timesheet_temp.of_getvalidationerrors(s_error)
									FOR li_err = 1 TO UpperBound(s_error) 
										IF Pos(s_error[li_err].s_message, 'Centre ') > 0 &
										AND Pos(s_error[li_err].s_message, 'not found.') > 0 THEN
											this.of_SetItem(ll_ts_row, 'centre', '')
										END IF
										IF Pos(s_error[li_err].s_message, 'Area ') > 0 &
										AND Pos(s_error[li_err].s_message, 'not found.') > 0 THEN
											this.of_SetItem(ll_ts_row, 'area', '')
										END IF
									NEXT
								END IF
							END IF 	//Hours populated
						NEXT			//job
					END IF			//found employee
				END IF				//not the totals row
			NEXT						//employee row
		NEXT							//page
	NEXT								//tab
	
	DESTROY lbo_job
	DESTROY lbo_employee
	DESTROY lbo_standard_control_account
	DESTROY lbo_occupation_rate
	DESTROY lbo_occupation
	DESTROY lbo_area
	DESTROY lds_popup
	DESTROY lbo_trade_union_rate

	this.of_SetFilter("")
	this.of_Filter()

	loo_excel.ActiveWorkbook.close(FALSE) 
	DESTROY loo_excel
	RETURN 1
END IF	

RETURN 1
end function

public function integer of_check_pay_period (string as_pr_yyyymm, ref string as_msg);
//************************************************************
// Object   :	n_bo_timesheet 
// Function :	of_check_pay_period
// Author   :	Monica Petersen
// Date     :	2017/05/03
// 	
// Arguments:	n_ds ads_timesheets			- datastore with all selected timesheets
//					long	al_future_timesheets - how many timesheets are in a future pay period
// 	
// Returns:		integer
// 	
// Desc:		
//		Check if the pay period has been advanced.
//
//		Conceivably you could have a mixture of Weekly and Biweekly paid unions, 
//		so you’d have to select max(work_date) by union_trade.pay_period_type 
//		from the candidate timesheets and loop through them.  
//		From there, you’d look at the Company pay period start offset 
//		for weekly/biweekly and add 1 to get the date of the next pay period start.  
//		By pay period type, you can say 
//		‘23 (bi)weekly timesheets are in a future pay period – OK to create cheques?’ 
//		with the default response set to No. 
// 	
//************************************************************

String	ls_union, ls_prev_union, ls_pp_type, ls_prev_pp_type
Long		ll_x, ll_ts_rows
Date		ld_max, ld_min, ld_next_pp_start_date
n_bo_pay_period	lbo_pay_period

//Break out reporting by union
Integer	li_y, li_union
String	ls_trade_union[], ls_pay_period[]
Date		ld_next_pp[], ld_min_ts[], ld_max_ts[]
Long		ll_future_timesheets[]

//Initialize variables
//ll_future_timesheets = 0
ls_prev_union = ''
ls_prev_pp_type = ''
as_msg = ''
ld_max = Date(1900,1,1)
ld_min = Date(2099,12,31)

//Look for timesheets with work dates in the next pay period
ll_ts_rows = this.of_RowCount()
FOR ll_x = 1 TO ll_ts_rows
	ls_union = this.of_GetItemString(ll_x, 'trade_union')
	
	//If timesheets are for several unions, refresh the union values.
	IF ls_union <> ls_prev_union THEN
		ls_prev_union = ls_union
		SELECT pay_period_type
		  INTO :ls_pp_type
		  FROM trade_union
		 WHERE book = :gnv_app.is_book
		   AND trade_union = :ls_union
		 USING sqlca;
		IF sqlca.sqlcode <> 0 THEN
			this.of_msg_db_error("Error reading pay period type from trade union " + ls_union)
			RETURN -1
		END IF
		
		//If the pay period type is different (weekly vs biweekly), need a new pp start date
		IF ls_pp_type <> ls_prev_pp_type THEN
			ls_prev_pp_type = ls_pp_type
			
			lbo_pay_period = CREATE n_bo_pay_period
			lbo_pay_period.of_SetTransaction()
			IF lbo_pay_period.of_get_next_pay_period_start(ls_pp_type, Left(as_pr_yyyymm, 4), ld_next_pp_start_date) = -1 THEN
				RETURN -1
			END IF
			DESTROY lbo_pay_period
		END IF
	END IF
		
	//Are we at the end?
	IF Not(IsNull(ld_next_pp_start_date)) THEN
		IF Date(this.of_GetItemDateTime(ll_x, 'work_date')) > ld_next_pp_start_date THEN
			
			//Find this union
			li_union = 1
			FOR li_y = 1 TO UpperBound(ls_trade_union)
				IF ls_trade_union[li_y] = ls_union THEN
					li_union = li_y
				END IF
			NEXT
			
			ls_trade_union[li_union] = ls_union
			ls_pay_period[li_union] = ls_pp_type
			ld_next_pp[li_union] = ld_next_pp_start_date
			ll_future_timesheets[li_union] ++
			
			//Craft an informative message
			IF Date(this.of_GetItemDateTime(ll_x, 'work_date')) < ld_min THEN
				ld_min_ts[li_union]  = Date(this.of_GetItemDateTime(ll_x, 'work_date'))
			END IF
			
			IF Date(this.of_GetItemDateTime(ll_x, 'work_date')) > ld_max THEN
				ld_max_ts[li_union]  = Date(this.of_GetItemDateTime(ll_x, 'work_date'))
			END IF
			
		END IF
	END IF
		
NEXT

as_msg = ''
FOR li_y = 1 TO UpperBound(ls_trade_union)
	IF ll_future_timesheets[li_y] > 0 THEN
		as_msg += "The current pay period for union " + ls_trade_union[li_y] + " (" + ls_pay_period[li_y] + ") ends on " + String(RelativeDate(ld_next_pp[li_y], -1), 'yyyy.mm.dd') &
				 + " but there are " + String(ll_future_timesheets[li_y]) &
				 + " timesheets for work done between " + String(ld_min_ts[li_y], 'yyyy.mm.dd') &
				 + " and " + String(ld_max_ts[li_y], 'yyyy.mm.dd') + ".~n~r" 
	END IF
NEXT
	
RETURN 1

end function

protected function string of_generatedelta (dwbuffer ae_buffer, long al_row);//************************************************************
// Object   :	n_cst_business_abio 
// Function :	of_GenerateDelta
// Author   :	Paul Bauermeister
// Date     :	2009/04/21
// 	
// Arguments:	dwbuffer ae_buffer
// 				long al_row
// 	
// Returns:		string
// 	
// Desc:			Generates the delta value to be recorded for the 
//					audit log, for the specified row within the specified 
//					buffer, based on the row status
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Integer			li_columns
Integer			li_index
String			ls_delta
String			ls_column_name
String			ls_from
String			ls_to
dwItemStatus	le_status

li_columns = Integer(This.ids_data.Object.Datawindow.Column.Count)

FOR li_index = 1 TO li_columns
	// Exclude computed columns - these will NOT have a period 
	// separating table name from column name in the DB name - 
	// and columns that are not updateable
	IF /*Pos(This.ids_data.Describe("#" + String(li_index) + &
			".DBName"), ".") > 0 AND*/ &
			Upper(This.ids_data.Describe("#" + String(li_index) + &
			".Update")) = "YES" THEN
		ls_from = ""
		ls_to = ""
		ls_column_name = This.ids_data.Describe("#" + String(li_index) + &
				".Name")
		
		le_status = This.ids_data.GetItemStatus(al_row, 0, ae_buffer)
		
		IF le_status = DataModified! OR ae_buffer = Delete! THEN
			// Get the original value from the specified buffer
			ls_from = This.of_GetItem(al_row, li_index, ae_buffer, TRUE)
			ls_from = of_format_data(ls_column_name, ls_from)
		END IF
		
		IF ae_buffer <> Delete! THEN
			// Get the new value from the specified buffer
			ls_to = This.of_GetItem(al_row, li_index, ae_buffer, FALSE)
			ls_to = of_format_data(ls_column_name, ls_to)
		END IF
		
		IF IsNull(ls_from) THEN ls_from = ""
		IF IsNull(ls_to) THEN ls_to = ""
		
		//Log everything if this is being captured from a field app
		IF Trim(ls_from) <> Trim(ls_to) &
		OR This.of_GetItem(al_row, 'file_type', Primary!, TRUE) = 'P' THEN
			IF ls_delta <> "" THEN ls_delta += " | "
			ls_delta += ls_column_name + " ~~ " + ls_from + " ~~ " + ls_to
		END IF
	END IF
NEXT

RETURN ls_delta

end function

on n_bo_timesheet.create
call super::create
end on

on n_bo_timesheet.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_timesheet 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/05/01
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

// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Timesheet")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_timesheet"

// use sqlca so premiums are in same transaction
This.of_SetTransaction(sqlca)

//Set primary key column
of_setpkcolumns({'book','employee','work_date','timesheet_item'})

//Required fields
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", FALSE)
This.of_AddValidationRule({"employee"}, "REQUIRED", &
		"", "Employee is Required", FALSE)
This.of_AddValidationRule({"work_date"}, "REQUIRED", &
		"", "Date is Required", FALSE)
This.of_AddValidationRule({"timesheet_item"}, "REQUIRED", &
		"", "Please specify a timesheet item", FALSE)
This.of_AddValidationRule({"gl_account"}, "REQUIRED", &
		"", "G/L Account is Required", TRUE)
This.of_AddValidationRule({"timesheet_item"}, "EXPRESSION", &
		"<<timesheet_item>> > 0", "Please specify a timesheet item", FALSE)
This.of_AddValidationRule({"trade_union"}, "EXPRESSION", &
		"<<file_type>> IN ('R') OR Len(<<trade_union>>) > 0", "Union is Required", TRUE)
This.of_AddValidationRule({"occupation"}, "EXPRESSION", &
		"<<file_type>> IN ('R') OR Len(<<occupation>>) > 0", "Occupation is Required", TRUE)
This.of_AddValidationRule({"restrict_flag"}, "REQUIRED", &
		"", "Restrict Flag is Required", FALSE)
This.of_AddValidationRule({"transact_flag"}, "REQUIRED", &
		"", "Transact Flag is Required", FALSE)
This.of_AddValidationRule({"pr_yyyymm"}, "REQUIRED", &
		"", "G/L yyyymm is Required", FALSE)
This.of_AddValidationRule({"wcb_class"}, "REQUIRED", &
		"", "WCB class is Required", FALSE)
This.of_AddValidationRule({"gst_rule"}, "REQUIRED", &
		"", "GST rule is Required", FALSE)

//valid codes
of_AddValidationRule({"shift"}, "EXPRESSION", &
		"<<shift>> IN ('1', '2', '3')", "Shift must be 1, 2, or 3", FALSE)	

of_AddValidationRule({"tah_spot_flag"}, "EXPRESSION", &
		"<<tah_spot_flag>> IN ('Y', 'N')", "Time and a half spot flag must be Y or N", FALSE)	

of_AddValidationRule({"ovr_spot_flag"}, "EXPRESSION", &
		"<<ovr_spot_flag>> IN ('Y', 'N')", "Overtime spot flag must be Y or N", FALSE)	

of_AddValidationRule({"transact_flag"}, "EXPRESSION", &
		"<<transact_flag>> IN ('Y', 'N')", "Costed must be 'Y'es or 'N'o", FALSE)	

of_AddValidationRule({"restrict_flag"}, "EXPRESSION", &
		"<<restrict_flag>> IN ('Y', 'N')", "Restrict? must be 'Y'es or 'N'o", FALSE)	

of_AddValidationRule({"centre"}, "EXPRESSION", &
		"<<file_type>> IN ('R') OR (Len(<<centre>>) > 0 AND Len(<<job>>) > 0) OR Len(<<job>>) = 0 OR IsNull(<<job>>)", "Centre required when job is populated", TRUE)	

of_AddValidationRule({"area"}, "EXPRESSION", &
		"<<file_type>> IN ('R') OR (Len(<<area>>) > 0 AND Len(<<job>>) > 0) OR Len(<<job>>) = 0 OR IsNull(<<job>>)", "Area required when job is populated", TRUE)	

of_AddValidationRule({"centre"}, "EXPRESSION", &
		"<<file_type>> IN ('R') OR (Len(<<centre>>) = 0 OR IsNull(<<centre>>)) OR (Len(<<job>>) > 0 AND Len(<<area>>) > 0)", "Job and area required when centre is populated", TRUE)	

of_AddValidationRule({"memo"}, "EXPRESSION", &
		"(Len(<<memo>>) > 0 OR <<file_type>> IN ('C', 'H', 'P'))", "If you are rejecting this timesheet, please provide an explanation in the memo field.  The remote app will display the timesheet with a red question mark.  Clicking the question mark will show the memo.", TRUE)	

//of_AddValidationRule({"work_date"}, "EXPRESSION", &
//		" (Today() >= work_date) OR IsNull(work_date) " ,  &
//		 "Date cannot be in the future", FALSE)			
		  
//of_AddValidationRule({"reg_hour"}, "EXPRESSION", &
//		"<<reg_hour>> + <<tah_hour>> + <<ovr_hour>> <= 24", &
//		"hrs must be < 24", FALSE)
		
of_AddValidationRule({"pr_yyyymm"}, "EXPRESSION", &
		"IsNumber(<<pr_yyyymm>>) AND Len(<<pr_yyyymm>>) = 6", &
		"G/L YYYYMM Must be 6 Digits", FALSE)
		
of_AddValidationRule({"pr_yyyymm"}, "EXPRESSION", &
		"(LEFT(<<pr_yyyymm>>,4)  >= '1990' AND LEFT(<<pr_yyyymm>>,4)  <= '2089') AND " + &  
		" (MID(<<pr_yyyymm>>,5,2)  >= '01' AND MID(<<pr_yyyymm>>,5,2)  <= '12')", &
		"Invalid G/L YYYYMM ", FALSE)
		
this.of_setcolumndefault('book', 			gnv_app.is_book)
this.of_setcolumndefault('shift', 			'1')
this.of_setcolumndefault('file_type', 		'C')
this.of_setcolumndefault('transact_flag', 'N')
this.of_setcolumndefault('tah_spot_flag', 'N')
this.of_setcolumndefault('ovr_spot_flag', 'N')
this.of_setcolumndefault('restrict_flag', 'N')
This.of_setcolumndefault('add_user_id', 	gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 	"TODAY" )
This.of_setcolumndefault('reg_hour',"0" )
This.of_setcolumndefault('tah_hour',"0" )
This.of_setcolumndefault('travel_hour',"0" )
This.of_setcolumndefault('reg_earn',"0" )
This.of_setcolumndefault('tah_earn',"0" )
This.of_setcolumndefault('ovr_earn',"0" )
This.of_setcolumndefault('travel_earn',"0" )
This.of_setcolumndefault('loa',"0" )
This.of_setcolumndefault('loa_hour',"0" )
This.of_setcolumndefault('mileage',"0" )
This.of_setcolumndefault('mileage_hour',"0" )
This.of_setcolumndefault('turnaround',"0" )
This.of_setcolumndefault('site_allowance',"0" )
This.of_setcolumndefault('taxi',"0" )
This.of_setcolumndefault('meal',"0" )
This.of_setcolumndefault('retro',"0" )
This.of_setcolumndefault('other_taxable_pay',"0" )
This.of_setcolumndefault('vehicle_allowance_paid',"0" )
This.of_setcolumndefault('ovr_hour',"0" )
This.of_setcolumndefault('pay_in_lieu_of_notice',"0" )
This.of_setcolumndefault('gst_amount',"0" )
This.of_setcolumndefault('total',"0" )

This.of_AddDBConstraint("fk_centre__area", 		/* constraint */ 			&
                        "area", 						/* column */ 				&
		                  "Centre", 					/* message */ 				&
								"Centre") 					/* reference table */

This.of_AddDBConstraint("fk_timesheet__division", 	/* constraint */ 			&
                        "division", 					/* column */ 				&
		                  "division not found", 		/* message */ 				&
								"division") 					/* reference table */

This.of_AddDBConstraint("fk_timesheet_premium__timesheet", 	/* constraint */ 			&
                        "employee", 								/* column */ 				&
		                  "Can't delete timesheet because premiums exist", /* message */ 	&
								"timesheet_premium") 					/* reference table */

This.of_AddDBConstraint("fk_timesheet__wcb_class", 	/* constraint */ 			&
                        "wcb_class", 								/* column */ 				&
		                  "WCB class not found", /* message */ 	&
								"wcb_class") 					/* reference table */

This.of_AddDBConstraint("cc_timesheet__gl_account", "gl_account", &
"Account not setup for the current fiscal year in the G/L account table", "Timesheet")

This.of_AddDBConstraint("pk_timesheet", "employee", &
"A timesheet for this employee/date/item", "Timesheet")


this.of_AddChild("timesheet_premium",	"n_bo_timesheet_premium")
this.of_AddChild("timesheet_premium_deleted",	"n_bo_timesheet_premium")




end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_timesheet 
// Event    :	bo_validate
// Author   :	Monica Petersen
// Date     :	2015/10/05
// 	
// Arguments:	long al_row
// 				string as_column
// 				string as_value
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

String		ls_cost_type, ls_job, ls_area, ls_centre, ls_file_type
String		ls_trade_union, ls_occupation
Decimal	ldec_daily_hours, ldec_today
Long		ll_employee, ll_book_rows, ll_count
Long		ll_employee_Rec, ll_person_Rec
DateTime	ldt_work_date
Date		ld_date
Int			li_rc = 1, li_timesheet_item
n_bo_standard_control_account	lbo_standard_control_account

IF Len(is_jc_labour_cost) > 0 THEN
ELSE
	//Use business object to retrieve control accounts
	lbo_standard_control_account = CREATE n_bo_standard_control_account
	lbo_standard_control_account.of_SetTransaction(sqlca)
	IF lbo_standard_control_account.of_Retrieve('') < 1 THEN
		this.of_msg_db_error("Error reading control account", sqlca)
		RETURN -1
	END IF
	is_jc_labour_cost = lbo_standard_control_account.of_GetItemString(1, 'jc_lab_cost')
	DESTROY lbo_standard_control_account

END IF
IF al_row > 0 THEN
	CHOOSE CASE lower(as_column)
			
		CASE "employee"
			ls_file_type = this.of_GetItemString(al_row, 'file_type')
			IF ls_file_type = 'C' THEN
				ll_employee = this.of_GetItemNumber(al_row, 'employee')
				SELECT person.employee, employee.employee
				INTO :ll_person_rec, :ll_employee_rec
				FROM person LEFT OUTER JOIN employee 
								  ON person.employee = employee.employee
								 AND employee.book = :gnv_app.is_book
				WHERE person.employee = :ll_employee
				USING itr_trans;
				IF Not IsNull(ll_person_rec) AND IsNull(ll_employee_rec) THEN
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, f_get_employee_name(ll_employee) + " (" + String(ll_employee) &
							+ ") appears to be a new employee entered by a field supervisor. This new employee’s H/R Person Entry and P/R Employee Entry must be completed before his/her timesheets can be marked as current.")
	
				END IF
			END IF
			
		CASE "job"
			IF this.of_GetItemString(al_row, 'gl_account') = is_jc_labour_cost THEN
				IF Len(this.of_GetItemString(al_row, 'job')) > 0 THEN
				ELSE
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, "G/L account is reserved for J/C labour costs, timesheet must be posted to a job.") 
				END IF
			END IF
			
		CASE "area"
			IF This.ids_data.Describe("selected.Name") = "selected" THEN
				IF this.ids_data.GetItemString(al_row, 'selected') = 'Y' THEN
					//The entry screen will force a valid area
					//no need for a message at this point
					IF Len(as_value) > 0 THEN
						IF Not(IsValid(ibo_area)) THEN
							ibo_area = CREATE n_bo_area
							ibo_area.of_SetTransaction()
						END IF
						
						ls_job = this.of_GetItemString(al_row, 'job')
						ls_area = as_value
						
						IF IsNull(ls_job) THEN ls_job = ''
						IF IsNull(ls_area) THEN ls_area = ''
						
						IF Len(ls_job) > 0 AND Len(ls_area) > 0 THEN
							IF ibo_area.of_Retrieve("book = '" + gnv_app.is_book 	&
													+ "' AND job = '" + ls_job					&
													+ "' AND area = '" + ls_area				&
													+ "'") <> 1 THEN
								li_rc = -1
								This.of_AddValidationError(al_row, as_column, Primary!, "Area " + ls_area &
																												+ " not found.") 
							END IF
						END IF
					END IF
				END IF
			END IF
			
		CASE "centre"
			IF This.ids_data.Describe("selected.Name") = "selected" THEN
				IF this.ids_data.GetItemString(al_row, 'selected') = 'Y' THEN
					//The entry screen will force a valid centre
					//no need for a message at this point
					IF this.of_GetItemString(al_row, 'gl_account') = is_jc_labour_cost AND Len(as_value) > 0 THEN
						//Add this to allow validation of import file
						IF Not(IsValid(ibo_centre)) THEN
							ibo_centre = CREATE n_bo_centre
							ibo_centre.of_SetTransaction()
						END IF
						
						ls_job = this.of_GetItemString(al_row, 'job')
						ls_area = this.of_GetItemString(al_row, 'area')
						ls_centre = as_value
						
						IF IsNull(ls_job) THEN ls_job = ''
						IF IsNull(ls_area) THEN ls_area = ''
						IF IsNull(ls_centre) THEN ls_centre = ''
						
						IF Len(ls_job) > 0 AND Len(ls_area) > 0 AND Len(ls_centre) > 0 THEN
							IF ibo_centre.of_Retrieve("book = '" + gnv_app.is_book 	&
													+ "' AND job = '" + ls_job					&
													+ "' AND area = '" + ls_area				&
													+ "' AND centre = '" +  ls_centre		&
													+ "'") <> 1 THEN
								li_rc = -1
								This.of_AddValidationError(al_row, as_column, Primary!, "Centre " + ls_centre &
																												+ " not found.") 
							ELSE
								ls_cost_type = ibo_centre.of_GetItemString(1, 'cost_type')
								IF Pos(ls_cost_type, 'L') + Pos(ls_cost_type, 'A') = 0 THEN
									li_rc = -1
									This.of_AddValidationError(al_row, as_column, Primary!, "Centre " + ls_job &
																													+ '/' + ls_area &
																													+ '/' + ls_centre &
																													+ " doesn't allow labour postings.") 
								END IF
			
								IF ibo_centre.of_GetItemString(1, 'active_flag') = 'N' AND ib_centres_must_be_open THEN
									li_rc = -1
									This.of_AddValidationError(al_row, as_column, Primary!, "Centre " + ls_job &
																													+ '/' + ls_area &
																													+ '/' + ls_centre &
																													+ " is closed to postings.") 
								END IF
							END IF	
						END IF
					END IF
				END IF
			END IF
									
		CASE "trade_union"
			IF This.ids_data.Describe("selected.Name") = "selected" THEN
				IF this.ids_data.GetItemString(al_row, 'selected') = 'Y' THEN
					//The entry screen will force a valid area
					//no need for a message at this point
					IF Len(as_value) > 0 AND this.of_GetItemString(al_row, 'file_type') <> 'R' AND this.of_GetItemNumber(al_row, 'cheque_no') = 0 THEN
						IF Not(IsValid(ibo_trade_union)) THEN
							ibo_trade_union = CREATE n_bo_trade_union
							ibo_trade_union.of_SetTransaction()
						END IF
						
						ls_trade_union = as_value
						
						IF IsNull(ls_trade_union) THEN ls_trade_union = ''
						
						IF Len(ls_trade_union) > 0 THEN
							IF ibo_trade_union.of_Retrieve ( "book = '" + gnv_app.is_book &
							+ "' AND trade_union = '" + ls_trade_union &
							+ "'") <> 1 THEN
								li_rc = -1
								This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union " + ls_trade_union &
																												+ " not found.") 
							ELSEIF ibo_trade_union.of_GetItemString(1, 'active_flag') <> 'Y' THEN
								li_rc = -1
								This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union " + ls_trade_union &
																												+ " not active.") 
								//Validate union has a rate set up																				
								IF Not(IsValid(ibo_trade_union_rate)) THEN
									ibo_trade_union_rate = CREATE n_bo_trade_union_rate
									ibo_trade_union_rate.of_SetTransaction()
								END IF
								
								ldt_work_date = this.of_GetItemDateTime(al_row, 'work_date')																	
								IF ibo_trade_union.of_Retrieve ( "book = '" + gnv_app.is_book &
								+ "' AND trade_union = '" + ls_trade_union &
								+ "' AND '" + String(ldt_work_date, 'yyyy.mm.dd') + "' BETWEEN effective_date AND expiry_date") <> 1 THEN
									li_rc = -1
									This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union " + ls_trade_union &
																												+ " does not have a rate set up for " + String(ldt_work_date, 'yyyy.mm.dd')) 
								END IF
							END IF
						ELSE
							li_rc = -1
							This.of_AddValidationError(al_row, as_column, Primary!, "Trade Union is required.") 
						END IF
					END IF
				END IF
			END IF
			
		CASE "occupation"
			IF This.ids_data.Describe("selected.Name") = "selected" THEN
				IF this.ids_data.GetItemString(al_row, 'selected') = 'Y' THEN
					//The entry screen will force a valid area
					//no need for a message at this point
					IF Len(as_value) > 0 AND this.of_GetItemString(al_row, 'file_type') <> 'R' THEN
						IF Not(IsValid(ibo_occupation)) THEN
							ibo_occupation = CREATE n_bo_occupation
							ibo_occupation.of_SetTransaction()
						END IF
						
						ls_trade_union = this.of_GetItemString(al_row, 'trade_union')
						ls_occupation = as_value
						
						IF IsNull(ls_trade_union) THEN ls_trade_union = ''
						IF IsNull(ls_occupation) THEN ls_occupation = ''
						
						IF Len(ls_trade_union) > 0 AND Len(ls_occupation) > 0 THEN
							IF ibo_occupation.of_Retrieve ( "book = '" + gnv_app.is_book &
							+ "' AND trade_union = '" + ls_trade_union &
							+ "' AND occupation = '" + ls_occupation &
							+ "'") <> 1 THEN
								li_rc = -1
								This.of_AddValidationError(al_row, as_column, Primary!, "Occupation " + ls_occupation &
																												+ " not found.") 
							ELSE
								IF Not(IsValid(ibo_occupation_rate)) THEN
									ibo_occupation_rate = CREATE n_bo_occupation_rate
									ibo_occupation_rate.of_SetTransaction()
								END IF
								ldt_work_date = this.of_GetItemDateTime(al_row, 'work_date')																	
								IF ibo_occupation_rate.of_Retrieve ( "book = '" + gnv_app.is_book &
									+ "' AND trade_union = '" + ls_trade_union &
									+ "' AND occupation = '" + ls_occupation &
									+ "' AND '" + String(ldt_work_date, 'yyyy.mm.dd') + "' BETWEEN effective_date AND expiry_date") <> 1 THEN
									li_rc = -1
									This.of_AddValidationError(al_row, as_column, Primary!, "Occupation " + ls_trade_union + "\" + ls_occupation &
																												+ " does not have a rate set up for " + String(ldt_work_date, 'yyyy.mm.dd')) 
								END IF
							END IF
						END IF
					END IF
				END IF
			END IF
			
		CASE "work_date"
			// for newly records only
			IF This.of_GetItemStatus(al_row,0,Primary!) = New! OR  This.of_GetItemStatus(al_row,0,Primary!) = NewModified!  THEN
				
				ld_date = Date(left(string(as_value),10))
				
				IF (DaysAfter(Today(), ld_date) > 65 OR DaysAfter(Today(), ld_date) < -730) THEN
					li_rc = -1
					This.of_AddValidationError(al_row, as_column, Primary!, "date more than 2 years ago or more than 65 in the future") 
				END IF	
			END IF
			
		CASE "reg_hour", "tah_hour", "ovr_hour"
			IF Len(as_value) > 0 THEN
				ll_employee = this.of_GetItemNumber(al_row, 'employee')
				ldt_work_date = this.of_GetItemDateTime(al_row, 'work_date')
				li_timesheet_item = this.of_GetItemNumber(al_row, 'timesheet_item')
				
				//How many hours worked today?
				SELECT sum(reg_hour) + sum(tah_hour) + sum(ovr_hour) + sum(travel_hour)
				  INTO :ldec_daily_hours
				  FROM timesheet
				 WHERE book 				= :gnv_app.is_book
					AND employee			= :ll_employee
					AND work_date	 		= :ldt_work_date 
					AND file_type 			= 'C'
					AND timesheet_item  <> :li_timesheet_item
				USING this.itr_trans;
				CHOOSE CASE itr_trans.sqlcode
					CASE -1
						li_rc = -1
						This.of_AddValidationError(al_row, as_column, Primary!, "Error getting employee " + String(ldt_work_date, 'yyyy.mm.dd') + " worked hours") 
					CASE 100
						ldec_daily_hours = 0
				END CHOOSE
				
				CHOOSE CASE as_column
					CASE "reg_hour"
						ldec_today = Dec(as_value) + this.of_GetItemNumber(al_Row, 'tah_hour')  + this.of_GetItemNumber(al_Row, 'ovr_hour') 
					CASE "tah_hour"
						ldec_today = Dec(as_value) + this.of_GetItemNumber(al_Row, 'reg_hour')  + this.of_GetItemNumber(al_Row, 'ovr_hour') 
					CASE "ovr_hour"
						ldec_today = Dec(as_value) + this.of_GetItemNumber(al_Row, 'tah_hour')  + this.of_GetItemNumber(al_Row, 'reg_hour') 
				END CHOOSE
				
				//jira 4799 - Delete P/R cheque that has >24 hours on a single day
//				IF ldec_daily_hours + ldec_today > 24 THEN
//					li_rc = -1
//					This.of_AddValidationError(al_row, as_column, Primary!, "more than 24 hours") 
//				END IF
			END IF
			
		CASE 'division'
			IF Not(IsValid(ibo_book)) THEN
				ibo_book = CREATE n_bo_book
				ibo_book.of_SetTransaction(sqlca)
			END IF
			ll_book_rows = ibo_book.of_Retrieve("book = '" + gnv_app.is_book + "'")
			IF ll_book_rows < 1 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Error reading book") 
			ELSE
				
				IF this.of_GetItemString(1, 'gl_account') >= gs_gl_account_division_required_floor THEN
					IF IsNull(as_value) OR Trim(as_value) = '' THEN
						li_rc = -1
						This.of_AddValidationError(al_row, as_column, Primary!, 'Division is required for G/L accounts above ' + gs_gl_account_division_required_floor + ".") 
					END IF
				END IF
			END IF
						
	END CHOOSE 
END IF


RETURN li_rc


end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_timesheet 
// Event    :	destructor
// Author   :	Monica Petersen
// Date     :	2017/05/03
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

//Destroy business objects
IF IsValid(ibo_premium_type) THEN DESTROY ibo_premium_type
IF IsValid(ibo_timesheet_premium) THEN DESTROY ibo_timesheet_premium
IF IsValid(ibo_employee_premium) THEN DESTROY ibo_employee_premium
IF IsValid(ibo_trade_union_premium) THEN DESTROY ibo_trade_union_premium
IF IsValid(ibo_trade_union) THEN DESTROY ibo_trade_union
IF IsValid(ibo_trade_union_rate) THEN DESTROY ibo_trade_union_rate
IF IsValid(ibo_occupation) THEN DESTROY ibo_occupation
IF IsValid(ibo_occupation_rate) THEN DESTROY ibo_occupation_rate

end event

