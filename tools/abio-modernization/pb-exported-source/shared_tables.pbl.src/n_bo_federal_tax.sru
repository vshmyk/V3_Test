$PBExportHeader$n_bo_federal_tax.sru
forward
global type n_bo_federal_tax from n_cst_business_abio
end type
end forward

global type n_bo_federal_tax from n_cst_business_abio
end type
global n_bo_federal_tax n_bo_federal_tax

forward prototypes
public function integer of_get_federal_td1_claim (datetime adt_effective_date, datetime adt_expiry_date, string as_file_type, ref decimal adc_claim_amount)
end prototypes

public function integer of_get_federal_td1_claim (datetime adt_effective_date, datetime adt_expiry_date, string as_file_type, ref decimal adc_claim_amount);//************************************************************
// Object   :	n_bo_federal_tax 
// Function :	of_get_federal_td1_claim
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	datetime adt_effective_date
// 				datetime adt_expiry_date
// 				string as_file_type
// 				decimal adt_claim_amount
// 	
// Returns:		integer  1 Success, 0 No Data, -1 Error in Retrieval
// 	
// Desc:			
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

Int		 li_return
Long		 ll_rc
String	 ls_where


ls_where = "CONVERT(varchar, effective_date, 112) <= '" + string(adt_effective_date, 'YYYYMMDD') +  "' " + &
						  " and CONVERT(varchar, expiry_date, 112) >= '" + string(adt_expiry_date, 'YYYYMMDD') + "'"  + &
						  " and file_type = '" + as_file_type + "'"

IF IsNull(adt_effective_date) OR IsNull(adt_expiry_date) OR IsNull(as_file_type) THEN
	gnv_error.of_add(90,gs_last_window,"R","Error reading federal_tax",-1,ls_where,"federal_tax")
	li_return = -1
	SetNull(adc_claim_amount)
ELSE
	ll_rc = This.of_retrieve(ls_where)
						  
   IF ll_rc > 0 THEN
		adc_claim_amount = This.of_GetItemDecimal(ll_rc,"federal_td1_claim")
		li_return = 1
		
	ELSE
		gnv_error.of_add(90,gs_last_window,"R","Can't find federal_tax",100,ls_where,"federal_tax")
		li_return = 0 
		SetNull(adc_claim_amount)
	END IF
END IF
				
RETURN li_return				
	
	
	
end function

on n_bo_federal_tax.create
call super::create
end on

on n_bo_federal_tax.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_federal_tax 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/04/22
// 	
// Arguments:	(None)
// 	
// Returns:		long
// 	
// Desc:			Initialize BO
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************

// Set the object description to be seen in messages to user
This.of_SetDescription("P/R Federal Tax")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_federal_tax"

// Force a new transaction for this business object
This.of_SetTransaction()


//Set primary key column
of_setpkcolumns({'effective_date'})



This.of_AddValidationRule({"effective_date"}, "UNIQUE", &
		"", "Federal tax already exists", FALSE)

This.of_AddValidationRule({"federal_td1_claim"}, "EXPRESSION", &
		"<<federal_td1_claim>> >= 8000 and  <<federal_td1_claim>> <= 20000", "Federal TD1 Claim must be between 8,000 and 20,000", FALSE)	
		
This.of_AddValidationRule({"cpp_annual_allowance"}, "EXPRESSION", &
		"<<cpp_annual_allowance>> >= 2000 and  <<cpp_annual_allowance>> <= 4000", "CPP Annual Allowance must be between 2000 and 4000", FALSE)	
		
This.of_AddValidationRule({"cpp_multiplier"}, "EXPRESSION", &
		"<<cpp_multiplier>> >= .02 and  <<cpp_multiplier>> <= .06", "CPP Multiplier must be between .02 and .06", FALSE)	
		
//This.of_AddValidationRule({"index_factor_percent"}, "EXPRESSION", &
//		"<<index_factor_percent>> >= 0 and <<index_factor_percent>> <= 2", "Index Factor Percent must be between 0 and 2", FALSE)	

This.of_AddValidationRule({"cpp_annual_maximum"}, "EXPRESSION", &
		"<<cpp_annual_maximum>> >= 700 and  <<cpp_annual_maximum>> <= 5000", "CPP Annual Maximum must be between 700 and 5000", FALSE)	
		
This.of_AddValidationRule({"ei_annual_max_premium"}, "EXPRESSION", &
		"<<ei_annual_max_premium>> >= 700 and  <<ei_annual_max_premium>> <= 5000", "EI Annual Maximum must be between 700 and 5000", FALSE)	
		
This.of_AddValidationRule({"ei_annual_max_earning"}, "EXPRESSION", &
		"<<ei_annual_max_earning>> >= 30000 and  <<ei_annual_max_earning>> <= 80000", "EI Annual Maximum must be between 30000 and 80000", FALSE)	
		
This.of_AddValidationRule({"ei_employer_multiplier"}, "EXPRESSION", &
		"<<ei_employer_multiplier>> >= 1 and  <<ei_employer_multiplier>> <= 3", "EI Employer Multiplier must be between 1 and 3", FALSE)	
		
This.of_AddValidationRule({"qpip_annual_max_premium"}, "EXPRESSION", &
		"(<<qpip_annual_max_premium>> >= 200 and  <<qpip_annual_max_premium>> <= 15000) OR <<qpip_annual_max_premium>> = 0 ", "QPIP Maximum Premium must be between 200 and 15000", FALSE)	
		
This.of_AddValidationRule({"qpip_annual_max_earning"}, "EXPRESSION", &
		"(<<qpip_annual_max_earning>> >= 20000 and  <<qpip_annual_max_earning>> <= 180000) OR <<qpip_annual_max_earning>> = 0", "QPIP Maximum Earning must be between 20000 and 180000", FALSE)	
		
This.of_AddValidationRule({"ei_employer_multiplier"}, "EXPRESSION", &
		"<<ei_employer_multiplier>> >= 1 and  <<ei_employer_multiplier>> <= 3", "QPIP Employer Multiplier must be between 1 and 3", FALSE)	
		
//This.of_AddValidationRule({"canada_employment_credit"}, "EXPRESSION", &
//		"<<canada_employment_credit>> = '' OR (<<canada_employment_credit>> >= 0.00 and  <<canada_employment_credit>> <= 5000.00)", "Canada Employment Credit must be between 0 and 5000", FALSE)	
		
This.of_AddValidationRule({"a_min_1"}, "EXPRESSION", &
		"<<a_min_1>> = 0", "Minimum annual taxable income starts at zero", FALSE)	
		
This.of_AddValidationRule({"r_1"}, "EXPRESSION", &
		"<<r_1>> >= 0 and  <<r_1>> <= 0.5", "Line 1 for Rate must be between 0 and .5", FALSE)	
		
This.of_AddValidationRule({"k_1"}, "EXPRESSION", &
		"<<k_1>> >= 0 and  <<k_1>> <= 30000", "Line 2 for Constant must be between 0 and 30,000", FALSE)	
		
This.of_setcolumndefault('file_type','C')
This.of_setcolumndefault('index_factor_percent','0')
//we need them to enter the date on an add, to trigger the ue_add_setup and enable all the fields
//This.of_SetColumnDefault("effective_date", String(Today(), "yyyy.mm.dd"))
This.of_SetColumnDefault("expiry_date", "2099.12.31")

end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_federal_tax 
// Event    :	bo_validate
// Author   :	Monica Petersen
// Date     :	2012/11/19
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

Integer	li_rc = 1

CHOOSE CASE as_column
	CASE 'a_min_2'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'a_min_1') &
		OR Double(as_value) > 500000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 2 of the Minimum annual taxable income must be between " + String(this.of_GetItemNumber(al_row, 'a_min_1')) + ' to 500,000')
		END IF
		
	CASE 'a_min_3'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'a_min_2') &
		OR Double(as_value) > 500000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 3 of the Minimum annual taxable income must be between " + String(this.of_GetItemNumber(al_row, 'a_min_2')) + ' to 500,000')
		END IF
		
	CASE 'a_min_4'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'a_min_3') &
		OR Double(as_value) > 500000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 4 of the Minimum annual taxable income must be between " + String(this.of_GetItemNumber(al_row, 'a_min_3')) + ' to 500,000')
		END IF
		
	CASE 'a_min_5'
		IF Double(as_value) <> 0 THEN	//prior to 2016 there were only 4 rows, so those entries this is 0.
			IF Double(as_value) < this.of_GetItemNumber(al_row, 'a_min_4') &
			OR Double(as_value) > 500000 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Line 5 of the Minimum annual taxable income must be between " + String(this.of_GetItemNumber(al_row, 'a_min_4')) + ' to 500,000')
			END IF
		END IF
		
	CASE 'r_2'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'r_1') &
		OR Double(as_value) > .5 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 2 for Rate must be between " + String(this.of_GetItemNumber(al_row, 'r_1')) + ' to 0.500')
		END IF
		
	CASE 'r_3'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'r_2') &
		OR Double(as_value) > .5  THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 3 for Rate must be between  " + String(this.of_GetItemNumber(al_row, 'r_2')) + ' to 0.500')
		END IF
		
	CASE 'r_4'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'r_3') &
		OR Double(as_value) > .5  THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 4 for Rate must be between  " + String(this.of_GetItemNumber(al_row, 'r_3')) + ' to 0.500')
		END IF
		
	CASE 'r_5'
		IF Double(as_value) <> 0 THEN	//prior to 2016 there were only 4 rows, so those entries this is 0.
			IF Double(as_value) < this.of_GetItemNumber(al_row, 'r_4') &
			OR Double(as_value) > .5  THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Line 5 for Rate must be between  " + String(this.of_GetItemNumber(al_row, 'r_4')) + ' to 0.500')
			END IF
		END IF
		
	CASE 'k_2'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'k_1') &
		OR Double(as_value) > 30000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 2 for Constant must be between " + String(this.of_GetItemNumber(al_row, 'k_1')) + ' to 30,000')
		END IF
		
	CASE 'k_3'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'k_2') &
		OR Double(as_value) > 30000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 3 of the Constant must be between " + String(this.of_GetItemNumber(al_row, 'k_2')) + ' to 30,000')
		END IF
		
	CASE 'k_4'
		IF Double(as_value) < this.of_GetItemNumber(al_row, 'k_3') &
		OR Double(as_value) > 30000 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Line 4 of the Constant must be between " + String(this.of_GetItemNumber(al_row, 'k_3')) + ' to 30,000')
		END IF
		
	CASE 'k_5'
		IF Double(as_value) <> 0 THEN	//prior to 2016 there were only 4 rows, so those entries this is 0.		
			IF Double(as_value) < this.of_GetItemNumber(al_row, 'k_4') &
			OR Double(as_value) > 30000 THEN
				li_rc = -1
				This.of_AddValidationError(al_row, as_column, Primary!, "Line 5 of the Constant must be between " + String(this.of_GetItemNumber(al_row, 'k_4')) + ' to 30,000')
			END IF
		END IF
		
	CASE 'index_factor_percent'
		IF Dec(as_value) < 0	OR Dec(as_value) > 10 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, "Index Factor Percent must be between 0 and 10")
		END IF
				
END CHOOSE

RETURN li_rc
end event

event bo_preupdate;call super::bo_preupdate;//************************************************************
// Object   :	n_bo_federal_tax 
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
Long							ll_rows
Long							ll_row
Long							ll_exist_row
Long							ll_deleted_row
Datetime						ldt_expiry
Datetime						ldt_effective
String						ls_where
n_bo_federal_tax		lbo_federal_tax
s_validation_error		lstr_validation_error[]

// For each new record, modify the expiry date of the preceding record 
// and set the expiry date of the new record
DO
	ll_row = This.ids_data.GetNextModified(ll_row, Primary!)
	
	IF ll_row > 0 THEN
		IF This.ids_data.GetItemStatus(ll_row, 0, Primary!) = NewModified! THEN
			IF NOT IsValid(lbo_federal_tax) THEN
				lbo_federal_tax = CREATE n_bo_federal_tax
				lbo_federal_tax.of_SetTransaction()
			END IF
			
			ldt_effective = This.of_GetItemDatetime(ll_row, "effective_date")
			
			// Retrieve rates before the current record so that the expiry 
			// date of the preceding record can be set to the day before 
			// the effective date of the current record
			
			ls_where = "effective_date < '" + &
					String(ldt_effective, "yyyy-mm-dd") + "'"
			
			ll_exist_row = lbo_federal_tax.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_federal_tax.of_SetSort("effective_date")
				lbo_federal_tax.of_Sort()
				
				ldt_expiry = lbo_federal_tax.of_GetItemDatetime(ll_exist_row, &
						"expiry_date")
				
				lbo_federal_tax.of_SetItem(ll_exist_row, "expiry_date", &
						Datetime(RelativeDate(Date(ldt_effective), -1)))
				
				li_rc = lbo_federal_tax.of_Update(FALSE, &
						lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					This.of_AddValidationErrors(lstr_validation_error)
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
			
			ls_where = "effective_date > '" + &
					String(This.of_GetItemDateTime(ll_row, "effective_date"), &
					"yyyy-mm-dd") + "'"
					
			ll_exist_row = lbo_federal_tax.of_Retrieve(ls_where)
			
			IF ll_exist_row > 0 THEN
				lbo_federal_tax.of_SetSort("effective_date")
				lbo_federal_tax.of_Sort()
				
				ldt_effective = lbo_federal_tax.of_GetItemDatetime(1, &
						"effective_date")
				
				This.of_SetItem(ll_row, "expiry_date", &
						Datetime(RelativeDate(Date(ldt_effective), -1)))
			END IF
		END IF
	END IF
LOOP UNTIL ll_row = 0

IF li_rc = 1 THEN
	// For each deleted record, modify the expiry date of the preceding record
	ll_rows = This.of_DeletedCount()
	
	FOR ll_row = 1 TO ll_rows
		IF NOT IsValid(lbo_federal_tax) THEN
			lbo_federal_tax = CREATE n_bo_federal_tax
			lbo_federal_tax.of_SetTransaction()
		END IF
		
		ll_exist_row = lbo_federal_tax.of_Retrieve("effective_date < '" + &
				String(This.of_GetItemDatetime(ll_row, "effective_date", &
				Delete!, FALSE), "yyyy-mm-dd") + "'")
		
		IF ll_exist_row > 0 THEN
			lbo_federal_tax.of_SetSort("effective_date")
			lbo_federal_tax.of_Sort()
			
			ldt_effective = lbo_federal_tax.of_GetItemDatetime( &
					ll_exist_row, "effective_date")
			
			// If the existing row is also in the list of rate records to 
			// be deleted, don't waste time updating it (updating records 
			// that are about to be deleted also causes the overall update 
			// to potentially fail due to changing values in the WHERE 
			// clause of the DELETE statement)
			FOR ll_deleted_row = 1 TO ll_rows
				IF This.of_GetItemDatetime(ll_deleted_row, "effective_date", &
						Delete!, FALSE) = ldt_effective THEN
					EXIT
				END IF
			NEXT
			
			IF ll_deleted_row > ll_rows THEN
				ldt_expiry = This.of_GetItemDatetime(ll_row, "expiry_date", &
						Delete!, FALSE)
				
				lbo_federal_tax.of_SetItem(ll_exist_row, "expiry_date", &
						ldt_expiry)
				
				li_rc = lbo_federal_tax.of_Update(FALSE, &
						lstr_validation_error)
				
				IF UpperBound(lstr_validation_error) > 0 THEN
					This.of_AddValidationErrors(lstr_validation_error)
				END IF
			END IF
		END IF
	NEXT
END IF

RETURN li_rc

end event

