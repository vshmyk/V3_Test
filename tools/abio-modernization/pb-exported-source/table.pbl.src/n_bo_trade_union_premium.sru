$PBExportHeader$n_bo_trade_union_premium.sru
forward
global type n_bo_trade_union_premium from n_cst_business_abio
end type
end forward

global type n_bo_trade_union_premium from n_cst_business_abio
end type
global n_bo_trade_union_premium n_bo_trade_union_premium

type variables
n_bo_employee_employee_premium					ibo_employee_employee_premium
string													is_message
Boolean	ib_validate_shift_premiums = TRUE
end variables

forward prototypes
public function boolean of_set_validation_premiums_on_delete (boolean ab_validate)
end prototypes

public function boolean of_set_validation_premiums_on_delete (boolean ab_validate);//************************************************************
// Object   :	n_bo_trade_union_premium 
// Function :	of_set_validation_premiums_on_delete
// Author   :	Viktar Shmyk
// Date     :	2017/05/18
// 	
// Arguments:	boolean ab_validate
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

ib_validate_shift_premiums = ab_validate

RETURN ab_validate
end function

on n_bo_trade_union_premium.create
call super::create
end on

on n_bo_trade_union_premium.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_trade_union_premium 
// Event    :	constructor
// Author   :	Viktar Shmyk
// Date     :	2010/09/27
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
This.of_SetDescription("Union Premiun")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_trade_union_premium"

// Set primary key columns
This.of_SetPKColumns({"book","trade_union","effective_date", "premium_type"})

This.of_AddValidationRule({"minimum_hour_rate"}, "REQUIRED", "", "Minimum rate is Required", TRUE)
This.of_AddValidationRule({"maximum_hour_rate"}, "REQUIRED", "", "Maximum rate is Required", TRUE)

This.of_AddValidationRule({"minimum_hour_rate"}, "EXPRESSION", "<<minimum_hour_rate>> <> 0 OR ( <<minimum_hour_rate>> = 0 AND premium_type IN ('SHIFT2','SHIFT3'))", "Only shift premiums can have a zero minimum rate", TRUE)
This.of_AddValidationRule({"minimum_hour_rate"}, "EXPRESSION", "<<maximum_hour_rate>> <> 0 OR ( <<maximum_hour_rate>> = 0 AND premium_type IN ('SHIFT2','SHIFT3'))", "Only shift premiums can have a zero maximum rate", TRUE)

This.of_AddValidationRule({"minimum_hour_rate", "maximum_hour_rate"}, "EXPRESSION", &
		"<<minimum_hour_rate>> <= <<maximum_hour_rate>>", "Minimum Rate May Not Be Greater Than Maximum Rate", TRUE)
		
This.of_AddValidationRule({"maximum_hour_rate"}, "EXPRESSION", &
		"<<maximum_hour_rate>> <= 99.99", "Maximum rate may not be more than $99.99", TRUE)
This.of_AddValidationRule({"minimum_hour_rate"}, "EXPRESSION", &
		"<<minimum_hour_rate>> <= 99.99", "Minimum rate may not be more than $99.99", TRUE)
		
//This is to prevent self-references. the employee premium business object creates a trade union premium business object
IF NOT IsValid(ibo_employee_employee_premium) THEN
	ibo_employee_employee_premium = CREATE n_bo_employee_employee_premium
	ibo_employee_employee_premium.of_SetTransaction()
END IF	
end event

event destructor;call super::destructor;//************************************************************
// Object   :	n_bo_trade_union_premium 
// Event    :	destructor
// Author   :	Lourdes Garcia
// Date     :	2011/09/19
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

IF IsValid(ibo_employee_employee_premium) THEN DESTROY(n_bo_employee_employee_premium)
end event

event bo_prerowdelete;call super::bo_prerowdelete;//************************************************************
// Object   :	n_bo_trade_union_premium 
// Event    :	bo_prerowdelete
// Author   :	Monica Petersen
// Date     :	2016/06/15
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

String	ls_premium_type, ls_trade_union
Long		ll_row, ll_rows, ll_count, ll_count_shift2, ll_count_shift3
DateTime	ldt_effective
Boolean	lb_return = TRUE
n_bo_premium_type	lbo_premium_type
n_bo_trade_union_trade_level_shift_premium		lbo_trade_union_trade_level_shift_premium
n_tr	ltr_trans

ltr_trans = CREATE n_tr
SQLCA.of_CopyTo(ltr_trans)
ltr_trans.of_Connect() 

IF al_row > 0 AND ib_validate_shift_premiums THEN
	
	ldt_effective = This.of_GetItemDateTime(al_row, "effective_date")
	ls_trade_union = This.of_GetItemString(al_row, "trade_union")
	
	lbo_premium_type = CREATE n_bo_premium_type
	lbo_premium_type.of_SetTransaction()
	
	ll_rows = this.of_RowCount()
	ll_count_shift2 = 0
	ll_count_shift3 = 0
	FOR ll_row = 1 TO ll_rows
		IF ll_row <> al_row THEN
			//Count how many premiums have exist for this union setup that reference shift 2
			//It might be that they're changing out one for the other, maybe because the overtime
			//coding is different
			ll_count_shift2 += lbo_premium_type.of_Retrieve("shift_2_flag = 'Y'" &
						+ "  AND premium_type = '" + This.of_GetItemString(ll_row, "premium_type")  + "'")
			
			//Count how many premiums have exist for this union setup that reference shift 3
			//It might be that they're changing out one for the other, maybe because the overtime
			//coding is different
			ll_count_shift3 += lbo_premium_type.of_Retrieve("shift_3_flag = 'Y'" &
						+ "  AND premium_type = '" + This.of_GetItemString(ll_row, "premium_type")  + "'")
		END IF
	NEXT
	lbo_trade_union_trade_level_shift_premium = CREATE n_bo_trade_union_trade_level_shift_premium
	lbo_trade_union_trade_level_shift_premium.of_SetTransaction(ltr_trans)
		
	IF ll_count_shift2 = 0 THEN
		//This is the only shift 2 premium, so they can't delete it if they
		//have a bunch of trade level premiums setup for shift 2
		//Check for non-zero shift 2 premiums
		ll_rows = lbo_trade_union_trade_level_shift_premium.of_Retrieve("book = '" + This.of_GetItemString(al_row, "book") &
				+ "' AND trade_union = '" + This.of_GetItemString(al_row, "trade_union") &
				+ "' AND shift_2_premium <> 0 " &
				+ "  AND effective_date = '" + String(This.of_GetItemDateTime(al_row, "effective_date"), 'yyyy.mm.dd') + "'")
	
		IF ll_rows > 0 THEN 
			IF lbo_premium_type.of_Retrieve("premium_type = '" + this.of_GetItemString(al_row, 'premium_type') + "'") > 0 THEN
				IF lbo_premium_type.of_GetItemString(1, 'shift_2_flag') = 'Y' THEN
					This.of_AddValidationError(al_row, "premium_type", Primary!, 'Cannot delete premium ' + this.of_GetItemString(al_row, 'premium_type') + ' because there are trade level shift 2 premium overrides.')
					lb_return =  FALSE
				END IF
			END IF
		END IF
	END IF
	
	IF ll_count_shift3 = 0 THEN
		//This is the only shift 3 premium, so they can't delete it if they
		//have a bunch of trade level premiums setup for shift 3
		
		//Check for non-zero shift 3 premiums
		ll_rows = lbo_trade_union_trade_level_shift_premium.of_Retrieve("book = '" + This.of_GetItemString(al_row, "book") &
				+ "' AND trade_union = '" + This.of_GetItemString(al_row, "trade_union") &
				+ "' AND shift_3_premium <> 0 " &
				+ "  AND effective_date = '" + String(This.of_GetItemDateTime(al_row, "effective_date"), 'yyyy.mm.dd') + "'")
		IF ll_rows > 0 THEN 
			IF lbo_premium_type.of_Retrieve("premium_type = '" + this.of_GetItemString(al_row, 'premium_type') + "'") > 0 THEN
				IF lbo_premium_type.of_GetItemString(1, 'shift_3_flag') = 'Y' THEN
					This.of_AddValidationError(al_row, "premium_type", Primary!, 'Cannot delete premium ' + this.of_GetItemString(al_row, 'premium_type') + ' because there are trade level shift 3 premium overrides.')
					lb_return =  FALSE
				END IF
			END IF
		END IF
	END IF

	DESTROY lbo_trade_union_trade_level_shift_premium
	DESTROY lbo_premium_type
END IF


RETURN lb_return
end event

