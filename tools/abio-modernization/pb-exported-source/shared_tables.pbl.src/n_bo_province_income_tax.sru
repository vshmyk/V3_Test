$PBExportHeader$n_bo_province_income_tax.sru
forward
global type n_bo_province_income_tax from n_cst_business_abio
end type
end forward

global type n_bo_province_income_tax from n_cst_business_abio
end type
global n_bo_province_income_tax n_bo_province_income_tax

forward prototypes
public function integer of_get_entry_count (string as_province, datetime adt_effective_date, ref long al_count)
end prototypes

public function integer of_get_entry_count (string as_province, datetime adt_effective_date, ref long al_count);//************************************************************
// Object   :	n_bo_province_income_tax 
// Function :	of_get_entry_count
// Author   :	Monica Petersen
// Date     :	2010/05/03
// 	
// Arguments:	string as_province
// 				datetime adt_effective_date
// 				datetime adt_expiry_date
// 				long al_count
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

Decimal   ldt_provincial_td1_claim
Int		 li_return
Long		 ll_rc
String	 ls_where


ls_where = "province = '" + as_province + &
						  "' and CONVERT(varchar, effective_date, 112) <= '" + string(adt_effective_date, 'YYYYMMDD') +  "'" + &
						   " and CONVERT(varchar, expiry_date, 112) >= '" + string(adt_effective_date, 'YYYYMMDD') + "'"

IF IsNull(ls_where) THEN
	gnv_error.of_add(90,gs_last_window,"R","Error reading province_income_tax",-1,ls_where,"province_income_tax")
	li_return = -1
	SetNull(al_count)
ELSE
	al_count = This.of_retrieve(ls_where)
						  
   IF al_count < 0 THEN
		gnv_error.of_add(90,gs_last_window,"R","Can't find province_rate",100,ls_where,"province_rate")
		li_return = -1 
		SetNull(al_count)
	ELSE
		li_return = 1
	END IF
END IF
				
RETURN li_return				
	
	
	


end function

on n_bo_province_income_tax.create
call super::create
end on

on n_bo_province_income_tax.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_province_income_tax 
// Event    :	constructor
// Author   :	Monica Petersen
// Date     :	2012/10/22
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
This.of_SetDescription("P/R Province Income Tax")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_province_income_tax"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'province', 'calculation_type', 'effective_date', 'a_min'})


This.of_AddValidationRule({'province', 'calculation_type', 'effective_date', 'a_min'}, "UNIQUE", &
		"", "Provincial income tax already exists", FALSE)


This.of_setcolumndefault('a_min', '0')
This.of_setcolumndefault('v_rate', '0')
This.of_setcolumndefault('kp_constant', '0')


This.of_SetColumnDefault("effective_date", String(Today(), "yyyy.mm.dd"))
This.of_SetColumnDefault("expiry_date", "2099.12.31")

end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_province_income_tax 
// Event    :	bo_preupdate
// Author   :	Monica Petersen
// Date     :	2012/10/22
// 	
// Arguments:	(None)
// 	
// Returns:		integer
// 	
// Desc:			Handle insertion of new rate in between existing 
//					rates, and removal from existing rates
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************


Integer						li_rc = 1
Long							ll_pit_rows, ll_pit_row
Long							ll_row, ll_ck_row
Long							ll_deleted_row, ll_deleted_rows
Datetime						ldt_expiry
Datetime						ldt_effective, ldt_target_effective
String						ls_province
String						ls_calculation_type
String						ls_where
n_bo_province_income_tax		lbo_province_income_tax
s_validation_error		lstr_validation_error[]

// For each new record, modify the expiry date of the preceding record 
// and set the expiry date of the new record
DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		IF This.ids_data.GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN
			IF NOT IsValid(lbo_province_income_tax) THEN
				lbo_province_income_tax = CREATE n_bo_province_income_tax
				lbo_province_income_tax.of_SetTransaction()
			END IF
			
			ldt_effective = This.of_GetItemDatetime(ll_row, "effective_date")
			
			// Retrieve rates before the current record so that the expiry 
			// date of the preceding record can be set to the day before 
			// the effective date of the current record
			
			ls_where = "province = '" + &
					This.of_GetItemString(ll_row, "province") + &
					"' AND calculation_type = '" + &
					This.of_GetItemString(ll_row, "calculation_type") + &
					"' AND effective_date < '" + &
					String(ldt_effective, "yyyy-mm-dd") + &
					"' AND expiry_date > '" + &
					String(ldt_effective, "yyyy-mm-dd") + "'"
			
			ll_pit_rows = lbo_province_income_tax.of_Retrieve(ls_where)
			
			IF ll_pit_rows < 0 THEN
				MessageBox("Error","Error retrieving previous records")
			ELSEIF ll_pit_rows > 0 THEN
				lbo_province_income_tax.of_SetSort("effective_date")
				lbo_province_income_tax.of_Sort()
				ldt_expiry = lbo_province_income_tax.of_GetItemDatetime(1, "expiry_date")

				FOR ll_pit_row = 1 TO ll_pit_rows
					lbo_province_income_tax.of_SetItem(ll_pit_row, "expiry_date", Datetime(RelativeDate(Date(ldt_effective), -1)))					
				NEXT
				
				li_rc = lbo_province_income_tax.of_Update(FALSE, lstr_validation_error)
				IF UpperBound(lstr_validation_error) > 0 THEN
					//This.of_AddValidationErrors(lstr_validation_error)
				END IF
				
				IF ldt_expiry > ldt_effective THEN
					// Set the current record's expiry date to what was the 
					// expiry date of the preceding record before the current 
					// record was created - this may get changed below
					This.of_SetItem(ll_row, "expiry_date", ldt_expiry)
				END IF
			END IF
			
			// Retrieve rates after the current record so that the expiry 
			// date of the current record can be set to the day before 
			// the effective date of the following record
			
			ls_where = "province = '" + &
					This.of_GetItemString(ll_row, "province") + &
					"' AND calculation_type = '" + &
					This.of_GetItemString(ll_row, "calculation_type") + &
					"' AND effective_date > '" + &
					String(This.of_GetItemDateTime(ll_row, "effective_date"), &
					"yyyy-mm-dd") + "'"
					
			ll_pit_rows = lbo_province_income_tax.of_Retrieve(ls_where)
			
			IF ll_pit_rows < 0 THEN
				MessageBox("Error","Error retrieving next records")
			ELSEIF ll_pit_rows > 0 THEN
				
				//We only need to know the next date
				lbo_province_income_tax.of_SetSort("effective_date")
				lbo_province_income_tax.of_Sort()
				ldt_effective = lbo_province_income_tax.of_GetItemDatetime(1, "effective_date")

				This.of_SetItem(ll_row, "expiry_date", Datetime(RelativeDate(Date(ldt_effective), -1)))
				
			END IF
		END IF
	END IF
LOOP UNTIL ll_row = 0

IF li_rc = 1 THEN
	// For each deleted record, modify the expiry date of the preceding record
	ll_deleted_rows = This.of_DeletedCount()
	
	FOR ll_deleted_row = 1 TO ll_deleted_rows
		IF NOT IsValid(lbo_province_income_tax) THEN
			lbo_province_income_tax = CREATE n_bo_province_income_tax
			lbo_province_income_tax.of_SetTransaction()
		END IF
		
		ls_province 			= This.of_GetItemString(ll_deleted_row, "province", Delete!, FALSE)
		ls_calculation_type 	= This.of_GetItemString(ll_deleted_row, "calculation_type", Delete!, FALSE)
		ldt_effective 			= This.of_GetItemDatetime(ll_deleted_row, "effective_date", Delete!, FALSE)
		ldt_expiry 				= This.of_GetItemDatetime(ll_deleted_row, "expiry_date", Delete!, FALSE)
		
		//Rows prior need to have their expiry date extended to cover the deleted entry
		ll_pit_rows = lbo_province_income_tax.of_Retrieve("province = '" + ls_province 	&
									+ "' AND calculation_type = '" + ls_calculation_type 			&
									+ "' AND effective_date < '" + String(ldt_effective, "yyyy-mm-dd") + "'")
		
		IF ll_pit_rows < 0 THEN
				MessageBox("Error","Error retrieving records prior to the deleted record")
		ELSEIF ll_pit_rows > 0 THEN
			
			lbo_province_income_tax.of_SetSort("effective_date DESC")
			lbo_province_income_tax.of_Sort()
			
			//Mark all records that match the most recent effective date
			ldt_target_effective = lbo_province_income_tax.of_GetItemDatetime(1, "effective_date")
			
			FOR ll_pit_row = 1 TO ll_pit_rows
				
				// If the existing row is also in the list of rate records to 
				// be deleted, don't waste time updating it (updating records 
				// that are about to be deleted also causes the overall update 
				// to potentially fail due to changing values in the WHERE 
				// clause of the DELETE statement)
				FOR ll_ck_row = 1 TO ll_pit_rows
					IF  lbo_province_income_tax.of_GetItemString(ll_ck_row, "province") = ls_province  						&
					AND lbo_province_income_tax.of_GetItemString(ll_ck_row, "calculation_type") = ls_calculation_type  &
					AND lbo_province_income_tax.of_GetItemDatetime(ll_ck_row, "effective_date") = ldt_effective THEN
						EXIT
					END IF
				NEXT
				
				IF ll_ck_row > ll_pit_rows THEN
					//We haven't come across the modified row
					IF lbo_province_income_tax.of_GetItemDatetime(ll_pit_row, "effective_date") = ldt_target_effective THEN
						lbo_province_income_tax.of_SetItem(ll_pit_row, "expiry_date", ldt_expiry)
					END IF
				END IF
					
			NEXT
			
			li_rc = lbo_province_income_tax.of_Update(FALSE, lstr_validation_error)
			
			IF UpperBound(lstr_validation_error) > 0 THEN
				//This.of_AddValidationErrors(lstr_validation_error)
			END IF
		END IF
	NEXT
END IF

RETURN li_rc

end event

