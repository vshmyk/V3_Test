$PBExportHeader$n_bo_timesheet_premium.sru
forward
global type n_bo_timesheet_premium from n_cst_business_abio
end type
end forward

global type n_bo_timesheet_premium from n_cst_business_abio
end type
global n_bo_timesheet_premium n_bo_timesheet_premium

type variables

n_bo_trade_union_trade_level_shift_premium	ibo_trade_union_trade_level_shift_premium
n_bo_trade_union 										ibo_trade_union
n_bo_occupation										ibo_occupation


n_bo_employee_premium		ibo_employee_premium
n_bo_trade_union_premium	ibo_trade_union_premium
n_bo_premium_type				ibo_premium_type


end variables

forward prototypes
public function integer of_insert_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item)
public function integer of_get_shift_premiums (string as_trade_union, string as_occupation, datetime adt_work, ref decimal adec_shift_2_rate, ref decimal adec_shift_3_rate, ref string as_msg)
public function integer of_generate_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item, string as_trade_union, string as_occupation, string as_shift, boolean ab_retain_manually_added_prem, s_parm astr_premium_addons, decimal adec_reg_hr, decimal adec_tah_hr, decimal adec_ovr_hr, ref decimal adec_reg_rate, ref decimal adec_tah_rate, ref decimal adec_ovr_rate)
public function integer of_generate_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item, string as_trade_union, string as_occupation, string as_shift, boolean ab_retain_manually_added_prem, s_parm astr_premium_addons)
end prototypes

public function integer of_insert_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item);
//************************************************************
// Object   :	n_bo_timesheet_premium 
// Function :	of_insert_timesheet_premiums
// Author   :	Monica Petersen
// Date     :	2010/12/21
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_work
// 				integer ai_item
// 	
// Returns:		integer
// 	
// Desc:			Timesheet premium rows come from both the employee and their trade union.  
//					
//					For the matching employee, we need to insert timesheet premium rows that correspond 
//						to matching employee premiums row that are effective 
//						on the timesheet date and where premium_type.active_flag = Y.  
//						These rows provide the premium type along with regular, time & half and overtime rates.
//					
//					For the matching trade union, we need to look at the subset of 
//						trade union premium rows that have premium_type.employee_specific_flag = N 
//						(if they were employee specific and applied to this employee, 
//						we would have gotten them from employee_premium) and 
//						premium_type.active_flag = Y.  
//						If premium_type.shift_2_flag = Y and timesheet.shift = '2', 
//						then we need to insert a row for this premium.  
//						Similarly if premium_type.shift_3_flag = Y and timesheet.shift = '3', 
//						then we need to insert a row for this premium.  The timesheet premium regular, 
//						time & half and overtime rates are set to the trade union 
//						premium minimum hour rate (which should equal the maximum hour rate).  
//						We are not expecting any other non employee specific benefits at this time.
//					
//					Timesheet_premium.reg_earn = round ( timesheet.reg_hour 
//					+ iif ( trade_union_rate.include_travel_flag = Y, timesheet.travel_hour, 0)) * timesheet_premium.reg_rate, 2).   
//					Timesheet_premium.tah_earn = round ( timesheet.tah_hour  * timesheet_premium.tah_rate, 2).  
//					Timesheet_premium.ovr_earn = round ( timesheet.ovr_hour  * timesheet_premium.ovr_rate, 2).
//
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long ll_ep_rows, ll_ep_row
Long ll_tp_rows, ll_tp_row

n_bo_trade_union_premium	lbo_trade_union_premium
n_bo_employee_premium		lbo_employee_premium
n_bo_timesheet_premium		lbo_timesheet_premium

lbo_trade_union_premium = CREATE n_bo_trade_union_premium
lbo_trade_union_premium.of_SetTransaction(sqlca)

lbo_employee_premium = CREATE n_bo_employee_premium
lbo_employee_premium.of_SetTransaction(sqlca)

lbo_timesheet_premium = CREATE n_bo_timesheet_premium
lbo_timesheet_premium.of_SetTransaction(sqlca)

// For the matching employee, we need to insert timesheet premium rows that correspond 
//	to matching employee premiums row that are effective 
//	on the timesheet date and where premium_type.active_flag = Y.  
//	These rows provide the premium type along with regular, time & half and overtime rates.
ll_ep_rows = lbo_employee_premium.of_retrieve("book = '" + as_book + "' AND employee = " 	&
				+ String(al_employee) + " AND active_flag = 'Y' AND effective_date <= '" 		&
				+ String(adt_work, 'yyyy.mm.dd') + "' AND expiry_date > '" + String(adt_work, 'yyyy.mm.dd') + "'")

FOR ll_ep_row = 1 TO ll_ep_rows
	ll_tp_row = lbo_timesheet_premium.of_InsertRow(0)
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'book', 				as_book)
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'employee', 			al_employee)
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'work_date', 		adt_work)
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'timesheet_item', 	ai_item)
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'premium_type', 	lbo_employee_premium.of_GetItemString(ll_ep_row, "premium_type"))
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'reg_earn', 			lbo_employee_premium.of_GetItemDecimal(ll_ep_row, "reg_earn"))
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'tah_earn', 			lbo_employee_premium.of_GetItemDecimal(ll_ep_row, "tah_earn"))
	lbo_timesheet_premium.of_SetItem(ll_tp_row, 'ovr_earn', 			lbo_employee_premium.of_GetItemDecimal(ll_ep_row, "ovr_earn"))
NEXT

DESTROY lbo_employee_premium
DESTROY lbo_timesheet_premium
DESTROY lbo_trade_union_premium


RETURN 1
end function

public function integer of_get_shift_premiums (string as_trade_union, string as_occupation, datetime adt_work, ref decimal adec_shift_2_rate, ref decimal adec_shift_3_rate, ref string as_msg);//************************************************************
// Object   :	n_bo_timesheet_premium 
// Function :	of_get_shift_premiums
// Author   :	Monica Petersen
// Date     :	2016/06/13
// 	
// Arguments:	string as_trade_union
// 				string as_occupation
// 				datetime adt_work
// 				decimal adec_shift_2_rate
// 				decimal adec_shift_3_rate
// 				string as_msg
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

String	ls_find, ls_trade_level
Long		ll_rows, ll_tusp_row


//Check for matching trade level shift premiums
IF Not(IsValid(ibo_trade_union)) THEN
	ibo_trade_union = CREATE n_bo_trade_union
	ibo_trade_union.of_SetTransaction()
END IF

IF Not(IsValid(ibo_occupation)) THEN
	ibo_occupation = CREATE n_bo_occupation
	ibo_occupation.of_SetTransaction()
END IF

//Get trade union to verify trade matches occupation trade
IF ibo_trade_union.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + as_trade_union + "'") < 1 THEN
	this.of_msg_db_error("Can't find trade union " + as_trade_union )
	RETURN -1
END IF

//Get occupation to compare trade levels
IF ibo_occupation.of_Retrieve("book = '" + gnv_app.is_book &
							 + "' AND trade_union = '" + as_trade_union &
							 + "' AND occupation = '" + as_occupation + "'") < 1 THEN
	this.of_msg_db_error("Can't find occupation " + as_trade_union + " / " + as_occupation)
	RETURN -1
END IF

IF Not(IsValid(ibo_trade_union_trade_level_shift_premium)) THEN
	ibo_trade_union_trade_level_shift_premium = CREATE n_bo_trade_union_trade_level_shift_premium
	ibo_trade_union_trade_level_shift_premium.of_SetTransaction()
END IF

ls_find = "trade_union = '" 	+ as_trade_union &
			+ "' AND effective_date <= '" + String(adt_work, 'yyyy.mm.dd') 							&
			+ "' AND expiry_date >= '" + String(adt_work, 'yyyy.mm.dd') + "'"
			
ll_rows = ibo_trade_union_trade_level_shift_premium.of_Retrieve(ls_find)
IF ll_rows < 0 THEN
	this.of_msg_db_error("Error reading trade level shift premiums " + ls_find)
	RETURN -1
END IF

ls_trade_level = ibo_occupation.of_GetItemString(1, 'level')
IF IsNull(ls_trade_level) THEN ls_trade_level = ''

//use trade level rates if available
IF ibo_occupation.of_GetItemString(1, 'trade') <> ibo_trade_union.of_GetItemString(1, 'trade') &
AND ll_rows > 0 THEN

	//Generate an error if trade levels are setup, but an employee has an trade different than the one setup for his union.
	//The trade levels are only meant for homogenous unions, i.e. all the same trade
	as_msg += "Occupation " + as_occupation 	&
			 + " is trade " + ibo_occupation.of_GetItemString(1, 'trade') 				&
			 + ", but trade union " + ibo_occupation.of_GetItemString(1, 'trade_union')  	&
			 + " is associated with trade " + ibo_trade_union.of_GetItemString(1, 'trade') &
			 + ". This isn't compatible for a union with trade level shift premium amounts."
	RETURN -1 	

ELSEIF ls_trade_level = 'JM' &
OR ll_rows = 0 THEN
	//Use premium amounts
	RETURN 0
ELSE					

	//Override
	ll_tusp_row = ibo_trade_union_trade_level_shift_premium.of_Find("trade_level = '" + ls_trade_level + "'")
	IF ll_tusp_row > 0 THEN
		adec_shift_2_rate = ibo_trade_union_trade_level_shift_premium.of_GetItemDecimal(ll_tusp_row, "shift_2_premium")
		adec_shift_3_rate = ibo_trade_union_trade_level_shift_premium.of_GetItemDecimal(ll_tusp_row, "shift_3_premium")
		RETURN 1
	ELSE
		RETURN 0
	END IF
	
END IF

RETURN 1
				

end function

public function integer of_generate_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item, string as_trade_union, string as_occupation, string as_shift, boolean ab_retain_manually_added_prem, s_parm astr_premium_addons, decimal adec_reg_hr, decimal adec_tah_hr, decimal adec_ovr_hr, ref decimal adec_reg_rate, ref decimal adec_tah_rate, ref decimal adec_ovr_rate);
//************************************************************
// Object   :	n_bo_timesheet_premium 
// Function :	of_generate_timesheet_premiums
// Author   :	Monica Petersen
// Date     :	2015/10/08
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_work
// 				integer ai_item
// 				string as_trade_union
// 				string as_shift
// 	
// Returns:		integer
// 	
// Desc:			Timesheet premium rows come from both the employee and their trade union.  
//					
//					For the matching employee, we need to insert timesheet premium rows that correspond 
//						to matching employee premiums row that are effective 
//						on the timesheet date and where premium_type.active_flag = Y.  
//						These rows provide the premium type along with regular, time & half and overtime rates.
//					
//					For the matching trade union, we need to look at the subset of 
//						trade union premium rows that have premium_type.employee_specific_flag = N 
//						(if they were employee specific and applied to this employee, 
//						we would have gotten them from employee_premium) and 
//						premium_type.active_flag = Y.  
//						If premium_type.shift_2_flag = Y and timesheet.shift = '2', 
//						then we need to insert a row for this premium.  
//						Similarly if premium_type.shift_3_flag = Y and timesheet.shift = '3', 
//						then we need to insert a row for this premium.  The timesheet premium regular, 
//						time & half and overtime rates are set to the trade union 
//						premium minimum hour rate (which should equal the maximum hour rate).  
//						We are not expecting any other non employee specific benefits at this time.
//					
//					Timesheet_premium.reg_earn = round ( timesheet.reg_hour 
//					+ iif ( trade_union_rate.include_travel_flag = Y, timesheet.travel_hour, 0)) * timesheet_premium.reg_rate, 2).   
//					Timesheet_premium.tah_earn = round ( timesheet.tah_hour  * timesheet_premium.tah_rate, 2).  
//					Timesheet_premium.ovr_earn = round ( timesheet.ovr_hour  * timesheet_premium.ovr_rate, 2).
//
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Long 		ll_pt_row
Long 		ll_ep_rows, ll_ep_row
Long 		ll_tp_row
Long 		ll_tup_rows, ll_tup_row
Long		ll_tpp_row, ll_tpp_rows
Long		ll_disp_row, ll_row
Long		ll_tu_row, ll_rows, ll_rc
Decimal	ldec_shift_2, ldec_shift_3, ldec_base_rate
String	ls_premium_type, ls_find, ls_msg
String	ls_empty[]

IF Not(IsValid(ibo_employee_premium)) THEN
	ibo_employee_premium = CREATE n_bo_employee_premium
	ibo_employee_premium.of_SetTransaction(sqlca)
END IF

IF Not(IsValid(ibo_trade_union_premium)) THEN
	ibo_trade_union_premium = CREATE n_bo_trade_union_premium
	ibo_trade_union_premium.of_SetTransaction(sqlca)
END IF
	
IF Not(IsValid(ibo_premium_type)) THEN
	ibo_premium_type = CREATE n_bo_premium_type
	ibo_premium_type.of_SetTransaction(sqlca)
END IF
	
IF Not(IsValid(ibo_trade_union)) THEN
	ibo_trade_union = CREATE n_bo_trade_union
	ibo_trade_union.of_SetTransaction(sqlca)
END IF

// For the matching employee, we need to insert timesheet premium rows that correspond 
//	to matching employee premiums row that are effective 
//	on the timesheet date and where premium_type.active_flag = Y.  
//	These rows provide the premium type along with regular, time & half and overtime rates.
ll_ep_rows = ibo_employee_premium.of_retrieve("book = '" + gnv_app.is_book &
				+ "' AND employee = " 	+ String(al_employee) &
				+ "  AND effective_date <= '" 		+ String(adt_work, 'yyyy.mm.dd') &
				+ "' AND expiry_date >= '" + String(adt_work, 'yyyy.mm.dd') + "'")

FOR ll_ep_row = 1 TO ll_ep_rows
	ls_premium_type = ibo_employee_premium.of_GetItemString(ll_ep_row, "premium_type")
	
	IF this.of_Find("employee = " + String(al_employee) + " AND work_date = Date('" + String(adt_work, 'yyyy.mm.dd') + "') AND timesheet_item = " + String(ai_item) + " AND premium_type = '" + ls_premium_type + "'") > 0 THEN
		Messagebox("Timesheet Premiums", "Employee " + String(al_employee) + " has more than one premium rate effective on " + String(adt_work, 'yyyy.mm.dd') &
										+ " for premium '" + ls_premium_type + "'. ~n~nPlease set the employee premium effective and/or expiry dates to correct this situation.")
		RETURN -1
	ELSE
	
		//First check the premium is valid in the timesheet's trade union.
		//If not, message the user and exclude the premium
		ll_tup_rows = ibo_trade_union_premium.of_Retrieve("book = '" + gnv_app.is_book 	&
										+ "' AND trade_union = '" + as_trade_union 	&
										+ "' AND premium_type = '" + ls_premium_type &
										+ "' AND effective_date <= '" + String(adt_work, 'yyyy.mm.dd') &
										+ "' AND expiry_date >= '" + String(adt_work, 'yyyy.mm.dd') &
										+ "'") 
		IF ll_tup_rows < 0 THEN
			Messagebox("Timesheet Premiums","Invalid query on trade union premium table")
			RETURN -1
		ELSEIF ll_tup_rows > 2 THEN
			Messagebox("Timesheet Premiums","Premium " + ls_premium_type + " has more than one rate effective in trade union " + as_trade_union &
							+ ", ~non " + String(adt_work, 'yyyy.mm.dd') + ". ~n~nPlease set the effective and/or expiry dates to correct this situation.")
			RETURN -1
		ELSEIF ll_tup_rows < 1 THEN
			Messagebox("Timesheet Premiums","Premium " + ls_premium_type + " isn't valid in trade union " + as_trade_union &
							+ ", ~nand so can't be added to timesheet " + String(al_employee) + "/" + String(adt_work, 'yyyy.mm.dd') + "/" + String(ai_item))
			//RETURN -1	//Jira 3924 - allow timesheet when employee's trade union doesn't have premium
		ELSE	
			//It's valid, are the employee rates within the trade union range?
			IF ibo_employee_premium.of_GetItemDecimal(ll_ep_row, 'reg_rate') < ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate') &
			OR ibo_employee_premium.of_GetItemDecimal(ll_ep_row, 'reg_rate') > ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate') THEN
				Messagebox("Timesheet Premiums","The rate for employee premium '" + ls_premium_type + "' is " + String(ibo_employee_premium.of_GetItemDecimal(ll_ep_row, 'reg_rate'), '$#.00') &
								+ ". This is outside the range currently ~ndefined for trade union " + as_trade_union &
								+ ", and so can't be added to timesheet.  ~n~nPlease adjust the regular rate on the employee premium for employee " + String(al_employee) &
								+ " to be between " + String(ibo_trade_union_premium.of_GetItemDecimal(1, 'minimum_hour_rate'), '$#.00' ) &
								+ " and " + String(ibo_trade_union_premium.of_GetItemDecimal(1, 'maximum_hour_rate'), '$#.00' ) + ".")
				RETURN -1
			ELSE	
				ll_pt_row = ibo_premium_type.of_retrieve("premium_type = '" + ls_premium_type + "' AND active_flag = 'Y'")
				IF ll_pt_row > 0 THEN
					
					IF ibo_premium_type.of_GetItemString(1, 'employee_specific_flag') = 'N' THEN 
						
						Messagebox("Timesheet Premiums","Premium " + ls_premium_type + " is no longer employee specific and so can't be added to timesheet " + String(al_employee) + "/" + String(adt_work, 'yyyy.mm.dd') + "/" + String(ai_item)) 
						RETURN -1
						
					ELSEIF ibo_premium_type.of_GetItemString(1, 'active_flag') = 'Y' THEN 
						
						ll_tp_row = this.of_InsertRow(0)
						this.of_SetItem(ll_tp_row, 'book', 				gnv_app.is_book)
						this.of_SetItem(ll_tp_row, 'employee', 		al_employee)
						this.of_SetItem(ll_tp_row, 'work_date', 		adt_work)
						this.of_SetItem(ll_tp_row, 'timesheet_item', ai_item)
						this.of_SetItem(ll_tp_row, 'premium_type', 	ls_premium_type)
						this.of_SetItem(ll_tp_row, 'reg_rate', 		ibo_employee_premium.of_GetItemDecimal(ll_ep_row, "reg_rate"))
						this.of_SetItem(ll_tp_row, 'tah_rate', 		ibo_employee_premium.of_GetItemDecimal(ll_ep_row, "tah_rate"))
						this.of_SetItem(ll_tp_row, 'ovr_rate', 		ibo_employee_premium.of_GetItemDecimal(ll_ep_row, "ovr_rate"))
						this.of_SetItem(ll_tp_row, 'reg_earn', 		Round(adec_reg_hr * this.of_GetItemDecimal(ll_tp_row, "reg_rate"), 2))
						this.of_SetItem(ll_tp_row, 'tah_earn', 		Round(adec_tah_hr * this.of_GetItemDecimal(ll_tp_row, "tah_rate"), 2))
						this.of_SetItem(ll_tp_row, 'ovr_earn', 		Round(adec_ovr_hr * this.of_GetItemDecimal(ll_tp_row, "ovr_rate"), 2))
						
						adec_reg_rate += this.of_GetItemDecimal(ll_tp_row, 'reg_rate')
						adec_tah_rate += this.of_GetItemDecimal(ll_tp_row, 'tah_rate')
						adec_ovr_rate += this.of_GetItemDecimal(ll_tp_row, 'ovr_rate')
							
					END IF
				END IF
			END IF
		END IF
	END IF
NEXT

//Jira 5406 - During Timesheet Entry for shifts 2 and 3, we look to see if there is a matching trade_union_premium in effect for that shift.  
//If the timesheet’s occupation is a non-JM trade level, we’d look to see if there is a corresponding trade_union_trade_level_shift_premium 
//in effect for that trade level.  If so, we use the corresponding shift_2(or 3)_premium amount.  Otherwise we use the  
//trade_union_premium.minimum_hour_rate.  In either case, we use the matching trade_union_premium.premium_type for the timesheet_premium entry.


//	For the matching trade union, we need to look at the subset of 
//		trade union premium rows that have premium_type.employee_specific_flag = N and 
//		premium_type.active_flag = Y.  
ll_tup_rows = ibo_trade_union_premium.of_retrieve("book = '" + gnv_app.is_book 							&
				+ "' AND trade_union = '" 	+ as_trade_union &
				+ "' AND effective_date <= '" + String(adt_work, 'yyyy.mm.dd') 							&
				+ "' AND expiry_date >= '" + String(adt_work, 'yyyy.mm.dd') + "'")

FOR ll_tup_row = 1 TO ll_tup_rows
	ls_premium_type = ibo_trade_union_premium.of_GetItemString(ll_tup_row, "premium_type") 
	ll_pt_row = ibo_premium_type.of_retrieve("premium_type = '" + ls_premium_type + "'")
	IF ll_pt_row > 0 THEN
		
		IF ibo_premium_type.of_GetItemString(1, 'active_flag') = 'Y' &
		AND ibo_premium_type.of_GetItemString(1, 'employee_specific_flag') = 'N' THEN 
		
			//	If premium_type.shift_2_flag = Y and timesheet.shift = '2', 
			//	then we need to insert a row for this premium.  
			IF (ibo_premium_type.of_GetItemString(1, 'shift_2_flag') = 'Y' 		&
				 AND as_shift = '2') 	&
				 																						&
			OR (ibo_premium_type.of_GetItemString(1, 'shift_3_flag') = 'Y' 		&
				 AND as_shift = '3')  	THEN

				//Check this premium hasn't been added as an employee premium
				IF this.of_Find("employee = " + String(al_employee) + " AND work_date = Date('" + String(adt_work, 'yyyy.mm.dd') + "') AND timesheet_item = " + String(ai_item) + " AND premium_type = '" + ls_premium_type + "'", 1, this.of_RowCount()) > 0 THEN
					this.of_msg_db_error("Premium type " + ls_premium_type + " has been specified for both employee " + String(al_employee) + " and union " + as_trade_union)
					RETURN -1
				ELSE
					
					ll_tp_row = this.of_InsertRow(0)
					this.of_SetItem(ll_tp_row, 'book', 				gnv_app.is_book)
					this.of_SetItem(ll_tp_row, 'employee', 		al_employee)
					this.of_SetItem(ll_tp_row, 'work_date', 		adt_work)
					this.of_SetItem(ll_tp_row, 'timesheet_item', ai_item)
					this.of_SetItem(ll_tp_row, 'premium_type', 	ls_premium_type)
					
					//Look for overriding trade level shift premiums
					ll_rc = this.of_get_shift_premiums(as_trade_union, as_occupation, adt_work, ldec_shift_2, ldec_shift_3, ls_msg)
					CHOOSE CASE ll_rc
						CASE -1
							MessageBox('Timesheet Shift Premiums', ls_msg)
							RETURN -1
						CASE 0
							ldec_base_rate = ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate")
						CASE 1
							IF as_shift = '2' THEN
								ldec_base_rate = ldec_shift_2
							ELSE
								ldec_base_rate = ldec_shift_3
							END IF
					END CHOOSE
					
					
					this.of_SetItem(ll_tp_row, 'reg_rate', 		ldec_base_rate)
					
					IF ibo_premium_type.of_GetItemString(1, 'overtime_hour_flag') = 'Y' THEN 
						IF ibo_premium_type.of_GetItemString(1, 'overtime_multiplier_flag') = 'Y' THEN 
							ll_tu_row = ibo_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND trade_union = '" + as_trade_union + "'")
							IF ll_tu_row > 0 THEN
								this.of_SetItem(ll_tp_row, 'tah_rate', ibo_trade_union.of_GetItemDecimal(1, 'tah_multiplier') * ldec_base_rate)
								this.of_SetItem(ll_tp_row, 'ovr_rate', ibo_trade_union.of_GetItemDecimal(1, 'ovr_multiplier') * ldec_base_rate)
							END IF
						ELSE
							this.of_SetItem(ll_tp_row, 'tah_rate', 	ldec_base_rate)
							this.of_SetItem(ll_tp_row, 'ovr_rate', 	ldec_base_rate)
						END IF
					ELSE
						this.of_SetItem(ll_tp_row, 'tah_rate', 	0)
						this.of_SetItem(ll_tp_row, 'ovr_rate', 	0)
					END IF
					
					this.of_SetItem(ll_tp_row, 'reg_earn', Round(adec_reg_hr * this.of_GetItemDecimal(ll_tp_row, "reg_rate"), 2))
					this.of_SetItem(ll_tp_row, 'tah_earn', Round(adec_tah_hr * this.of_GetItemDecimal(ll_tp_row, "tah_rate"), 2))
					this.of_SetItem(ll_tp_row, 'ovr_earn', Round(adec_ovr_hr * this.of_GetItemDecimal(ll_tp_row, "ovr_rate"), 2))
					adec_reg_rate += this.of_GetItemDecimal(ll_tp_row, 'reg_rate')
					adec_tah_rate += this.of_GetItemDecimal(ll_tp_row, 'tah_rate')
					adec_ovr_rate += this.of_GetItemDecimal(ll_tp_row, 'ovr_rate')
				END IF
			END IF
		END IF
	END IF
NEXT

//Next, add premiums that were manually added to the timesheet
IF ab_retain_manually_added_prem THEN
	ll_tpp_rows = UpperBound(astr_premium_addons.s_parm)
	FOR ll_tpp_row = 1 TO ll_tpp_rows
		ls_premium_type = astr_premium_addons.s_parm[ll_tpp_row]
			
		//Check this premium hasn't been added already
		IF this.of_Find("employee = " + String(al_employee) + " AND work_date = Date('" + String(adt_work, 'yyyy.mm.dd') + "') AND timesheet_item = " + String(ai_item) + " AND premium_type = '" + ls_premium_type + "'", 1, this.of_RowCount()) = 0 THEN
			ll_tup_row = ibo_trade_union_premium.of_Find("premium_type = '" + ls_premium_type + "'", 1, ibo_trade_union_premium.of_RowCount())
			IF ll_tup_row > 0 THEN
				ll_tp_row = this.of_InsertRow(0)
				this.of_SetItem(ll_tp_row, 'book', 				gnv_app.is_book)
				this.of_SetItem(ll_tp_row, 'employee', 		al_employee)
				this.of_SetItem(ll_tp_row, 'work_date', 		adt_work)
				this.of_SetItem(ll_tp_row, 'timesheet_item', ai_item)
				this.of_SetItem(ll_tp_row, 'premium_type', 	ls_premium_type)
				this.of_SetItem(ll_tp_row, 'reg_rate', 		ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate"))
				
				ll_pt_row = ibo_premium_type.of_retrieve("premium_type = '" + ls_premium_type + "'")
				IF ll_pt_row > 0 THEN
					
					IF ibo_premium_type.of_GetItemString(1, 'overtime_hour_flag') = 'Y' THEN 
						IF ibo_premium_type.of_GetItemString(1, 'overtime_multiplier_flag') = 'Y' THEN 
							ll_tu_row = ibo_trade_union.of_Retrieve("book = '" + gnv_app.is_book + "' AND trade_union = '" + as_trade_union + "'")
							IF ll_tu_row > 0 THEN
								this.of_SetItem(ll_tp_row, 'tah_rate', ibo_trade_union.of_GetItemDecimal(1, 'tah_multiplier') * ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate"))
								this.of_SetItem(ll_tp_row, 'ovr_rate', ibo_trade_union.of_GetItemDecimal(1, 'ovr_multiplier') * ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate"))
							END IF
						ELSE
							this.of_SetItem(ll_tp_row, 'tah_rate', ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate"))
							this.of_SetItem(ll_tp_row, 'ovr_rate', ibo_trade_union_premium.of_GetItemDecimal(ll_tup_row, "minimum_hour_rate"))
						END IF
					END IF
				END IF
				this.of_SetItem(ll_tp_row, 'reg_earn', Round(adec_reg_hr * this.of_GetItemDecimal(ll_tp_row, "reg_rate"), 2))
				this.of_SetItem(ll_tp_row, 'tah_earn', Round(adec_tah_hr * this.of_GetItemDecimal(ll_tp_row, "tah_rate"), 2))
				this.of_SetItem(ll_tp_row, 'ovr_earn', Round(adec_ovr_hr * this.of_GetItemDecimal(ll_tp_row, "ovr_rate"), 2))
				adec_reg_rate += this.of_GetItemDecimal(ll_tp_row, 'reg_rate')
				adec_tah_rate += this.of_GetItemDecimal(ll_tp_row, 'tah_rate')
				adec_ovr_rate += this.of_GetItemDecimal(ll_tp_row, 'ovr_rate')
			END IF
		END IF
	NEXT
END IF

RETURN 1
end function

public function integer of_generate_timesheet_premiums (string as_book, long al_employee, datetime adt_work, integer ai_item, string as_trade_union, string as_occupation, string as_shift, boolean ab_retain_manually_added_prem, s_parm astr_premium_addons);//************************************************************
// Object   :	n_bo_timesheet_premium 
// Function :	of_generate_timesheet_premiums
// Author   :	Monica Petersen
// Date     :	2017/11/26
// 	
// Arguments:	string as_book
// 				long al_employee
// 				datetime adt_work
// 				integer ai_item
// 				string as_trade_union
// 				string as_occupation
// 				string as_shift
// 				boolean ab_retain_manually_added_prem
// 				s_parm astr_premium_addons
// 	
// Returns:		integer
// 	
// Desc:			only the timesheet import function needs the rates and hours
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Decimal	ldec_reg_rate, ldec_tah_rate, ldec_ovr_rate

//Start with no premiums
this.of_Reset()

RETURN of_generate_timesheet_premiums(as_book, al_employee, adt_work, ai_item, as_trade_union, as_occupation, as_shift, ab_retain_manually_added_prem, astr_premium_addons, &
0,0,0, ldec_reg_rate, ldec_tah_rate, ldec_ovr_rate)
end function

on n_bo_timesheet_premium.create
call super::create
end on

on n_bo_timesheet_premium.destroy
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
This.of_SetDescription("P/R Timesheet Premium")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_timesheet_premium"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','employee','work_date','timesheet_item', 'premium_type'})

This.of_AddValidationRule({'book','employee','work_date','timesheet_item', 'premium_type'}, "UNIQUE", &
		"", "Timesheet Premium Already Exists", FALSE)

This.of_AddDBConstraint("fk_timesheet_premium__premium_type", 		/* constraint */ 			&
                        "premium_type", 						/* column */ 				&
		                  "Premium not found", 							/* message */ 				&
								"premium_type") 					/* reference table */

This.of_AddDBConstraint("fk_timesheet_premium__book", 	/* constraint */ 			&
                        "book", 					/* column */ 				&
		                  "book not found", 		/* message */ 				&
								"book") 					/* reference table */

This.of_AddDBConstraint("fk_timesheet_premium__timesheet", "employee", &
"Parent timesheet not found", "Timesheet")


end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_timesheet_premium 
// Event    :	bo_prerowdelete
// Author   :	Monica Petersen
// Date     :	2011/08/30
// 	
// Arg:		al_row - Row to be deleted
//
// Return:	Boolean - TRUE=Allow delete, FALSE=Prevent delete
//
// Desc:		This event is triggered before deleting a row from the 
//				datastore, and gives an opportunity to prevent the deletion
//
//************************************************************
// Modifications:
// Date			Author					Comments
//------------------------------------------------------------
// 
//************************************************************

Long		ll_ts_rows

n_bo_timesheet			lbo_timesheet



IF al_row > 0 THEN
	
	IF NOT IsValid(lbo_timesheet) THEN
		lbo_timesheet = CREATE n_bo_timesheet
		lbo_timesheet.of_SetTransaction()
	END IF
	
	ll_ts_rows = lbo_timesheet.of_Retrieve("book = '" + This.of_GetItemString(al_row, "book") &
			+ "' and employee = " + String(This.of_GetItemNumber(al_row, "employee")) &
			+ " AND work_date = '" + String(This.of_GetItemDateTime(al_row, "work_date"), 'yyyy.mm.dd') &
			+ "' AND timesheet_item = " + String(This.of_GetItemNumber(al_row, "timesheet_item")))
	IF ll_ts_rows > 0 THEN
		IF lbo_timesheet.of_GetItemNumber(1, 'cheque_no') = 0 THEN
			RETURN TRUE
		ELSE
			MessageBox('Timesheet Premium', 'Cannot delete this premium because it is part of cheque ' + String(lbo_timesheet.of_GetItemNumber(1, 'cheque_no')))
			This.of_AddValidationError(al_row, "premium_type", Primary!, "Deletion Disallowed. Timesheet is already part of a cheque")
			RETURN FALSE
		END IF
	END IF
	
	IF IsValid(lbo_timesheet) THEN DESTROY lbo_timesheet
END IF


RETURN TRUE
end event

event destructor;call super::destructor;
IF IsValid(ibo_trade_union_trade_level_shift_premium) THEN DESTROY ibo_trade_union_trade_level_shift_premium
IF IsValid(ibo_trade_union) THEN DESTROY ibo_trade_union
IF IsValid(ibo_occupation) THEN DESTROY ibo_occupation
IF IsValid(ibo_employee_premium) THEN DESTROY ibo_employee_premium
IF IsValid(ibo_trade_union_premium) THEN DESTROY ibo_trade_union_premium
IF IsValid(ibo_premium_type) THEN DESTROY ibo_premium_type

end event

