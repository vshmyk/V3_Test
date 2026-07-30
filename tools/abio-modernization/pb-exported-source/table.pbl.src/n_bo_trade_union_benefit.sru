$PBExportHeader$n_bo_trade_union_benefit.sru
forward
global type n_bo_trade_union_benefit from n_cst_business_abio
end type
end forward

global type n_bo_trade_union_benefit from n_cst_business_abio
end type
global n_bo_trade_union_benefit n_bo_trade_union_benefit

on n_bo_trade_union_benefit.create
call super::create
end on

on n_bo_trade_union_benefit.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_trade_union_benefit 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2010/10/13
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
This.of_SetDescription("Trade Union Benefit")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_trade_union_benefit"

this.of_SetTransaction(sqlca)

// Set primary key columns
This.of_SetPKColumns({"book","trade_union", "effective_date", "benefit_type"})

// Validation Rules
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", TRUE)
This.of_AddValidationRule({"trade_union"}, "REQUIRED", &
		"", "Trade Union is Required", TRUE)
This.of_AddValidationRule({"effective_date"}, "REQUIRED", &
		"", "Effective Date is Required", TRUE)
This.of_AddValidationRule({"benefit_type"}, "REQUIRED", &
		"", "Benefit Type is Required", TRUE)
This.of_AddValidationRule({"book", "trade_union", "effective_date", "benefit_type"}, "UNIQUE", &
		"", "Trade Union Must be Unique within Book", FALSE)
This.of_AddValidationRule("tax_type", "EXPRESSION", &
		"<<tax_type>> IN ('N', 'G', 'H', 'P')", &
		"Tax Type Must be 'N'one, 'G'st, 'H'st or 'P'st (includes GST)", FALSE)

// Defaults
This.of_SetColumnDefault('tax_type','N')
This.of_SetColumnDefault('regular_rate','0')
This.of_SetColumnDefault('time_and_half_rate','0')
This.of_SetColumnDefault('overtime_rate','0')
This.of_SetColumnDefault('base_rate','0')
This.of_SetColumnDefault('sched_base_rate','0')
This.of_SetColumnDefault('all_hr_reg_rate','0')

// Add DB Constraints
This.of_AddDBConstraint("pk_trade_union_benefit", "trade_union_benefit", "Trade Union Benefit", "")
This.of_AddDBConstraint("fk_trade_union_benefit__book", "trade_union_benefit", &
		"Book not found for Trade Union Benefit", "Book")
This.of_AddDBConstraint("fk_trade_union_benefit__vendor", "vendor", &
		"Corresponding Vendor not found", "Vendor")
This.of_AddDBConstraint("fk_trade_union_benefit__trade_union_benefit_type", "trade_union_benefit", &
		"Benefit not found for Trade Union Benefit", "Trade Union Benefit Type")
		

end event

event bo_validate;call super::bo_validate;//************************************************************
// Object   :	n_bo_trade_union_benefit 
// Event    :	bo_validate
// Author   :	Monica Petersen
// Date     :	2012/09/05
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

Integer					li_rc = 1
Long						ll_row
String					ls_vendor_province
n_bo_vendor				lbo_vendor
n_bo_province_rate	lbo_province_rate

IF as_column = "tax_type" AND as_value <> 'N' AND Len(this.of_GetItemString(al_row, 'vendor')) > 0 THEN
	// Ensure that the tax type exists for the current vendor or vendor
	lbo_vendor = CREATE n_bo_vendor
	lbo_vendor.of_SetTransaction()
	
	ll_row = lbo_vendor.of_Retrieve("book = '" + gnv_app.of_get_book() + "' AND vendor = '" + this.of_GetItemString(al_row, 'vendor') + "'")
	
	IF ll_row > 0 THEN
		ls_vendor_province = lbo_vendor.of_GetItemString(1, "province")
		
		lbo_province_rate = CREATE n_bo_province_rate
		lbo_province_rate.of_SetTransaction()
		
		ll_row = lbo_province_rate.of_Retrieve("province = '" + ls_vendor_province + "'")
		
		IF ll_row < 1 THEN
			li_rc = -1
			This.of_AddValidationError(al_row, as_column, Primary!, ls_vendor_province + " Not in Province Rate table")
		ELSE
			lbo_province_rate.of_SetSort("effective_date DESC")
			lbo_province_rate.of_Sort()
			
			CHOOSE CASE as_value
				CASE "H"
					IF lbo_province_rate.of_GetItemDecimal(1, 'hst_percent') = 0 THEN
						//li_rc = -1
						//This.of_AddValidationError(al_row, as_column, Primary!, this.of_GetItemString(al_row, 'vendor') + " is located in " + ls_vendor_province + ", which does not have HST rates")
						MessageBox("Benefit Vendor Tax Type", "Benefits vendor " + lbo_vendor.of_GetItemString(1, 'name') + ' (' + this.of_GetItemString(al_row, 'vendor') + ") is located in " + ls_vendor_province + ", which does not have HST rates.  Please select a valid tax type for the benefit invoice.")
					END IF
				CASE "G"
					IF lbo_province_rate.of_GetItemDecimal(1, 'gst_percent') = 0 THEN
						//li_rc = -1
						//This.of_AddValidationError(al_row, as_column, Primary!, this.of_GetItemString(al_row, 'vendor') + " is located in " + ls_vendor_province + ", which does not have GST rates")
						MessageBox("Benefit Vendor Tax Type", "Benefits vendor " + lbo_vendor.of_GetItemString(1, 'name') + ' (' + this.of_GetItemString(al_row, 'vendor') + ") is located in " + ls_vendor_province + ", which does not have GST rates.  Please select a valid tax type for the benefit invoice.")
					END IF
				CASE "P"
					IF lbo_province_rate.of_GetItemDecimal(1, 'pst_percent') = 0 THEN
						//li_rc = -1
						//This.of_AddValidationError(al_row, as_column, Primary!, this.of_GetItemString(al_row, 'vendor') + " is located in " + ls_vendor_province + ", which does not have PST rates")
						MessageBox("Benefit Vendor Tax Type", "Benefits vendor " + lbo_vendor.of_GetItemString(1, 'name') + ' (' + this.of_GetItemString(al_row, 'vendor') + ") is located in " + ls_vendor_province + ", which does not have PST rates.  Please select a valid tax type for the benefit invoice.")
					END IF
			END CHOOSE
		END IF
	ELSE
		li_rc = -1
		This.of_AddValidationError(al_row, as_column, Primary!, "Missing vendor Record for " + gnv_app.of_get_book())
	END IF
END IF

IF IsValid(lbo_vendor) THEN DESTROY lbo_vendor
IF IsValid(lbo_province_rate) THEN DESTROY lbo_province_rate

RETURN li_rc


end event

