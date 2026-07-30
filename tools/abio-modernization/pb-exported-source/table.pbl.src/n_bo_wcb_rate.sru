$PBExportHeader$n_bo_wcb_rate.sru
forward
global type n_bo_wcb_rate from n_cst_business_abio
end type
end forward

global type n_bo_wcb_rate from n_cst_business_abio
end type
global n_bo_wcb_rate n_bo_wcb_rate

forward prototypes
public function integer of_get_previous_rates (string as_book, string as_wcb_class, ref decimal adc_rate, ref decimal adc_max)
end prototypes

public function integer of_get_previous_rates (string as_book, string as_wcb_class, ref decimal adc_rate, ref decimal adc_max);//************************************************************
// Object   :	n_bo_wcb_rate 
// Function :	of_get_previous_rates
// Author   :	Lourdes Garcia
// Date     :	2012/01/06
// 	
// Arguments:	string as_book
// 				string as_wcb_class
// 				decimal adc_rate
// 				decimal adc_max
// 	
// Returns:		integer
// 	
// Desc:				-1 Error; 0 Nothing retrieved; 1 success
//					Retrieves rate and annual maximum
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************



Int		li_return
Long		ll_rc

IF IsNull(as_book) or IsNull(as_wcb_class) THEN
	li_return = -1
	SetNull(adc_rate)
	SetNull(adc_max)
ELSE
	ll_rc = This.of_retrieve("book = '" + string(as_book) + "' and wcb_class = '" + string(as_wcb_class) + "'")
	This.of_SetSort("tax_year DESC")
	This.of_Sort()
	// to retrieve latest year
	
	IF ll_rc > 0 THEN
		adc_rate = This.of_GetItemDecimal(1,"wcb_rate")
		adc_max = This.of_GetItemDecimal(1,"wcb_annual_maximum")
		li_return = 1
	ELSE
		SetNull(adc_rate)
		SetNull(adc_max)
		li_return = 0	
	END IF
END IF	
RETURN li_return	
end function

on n_bo_wcb_rate.create
call super::create
end on

on n_bo_wcb_rate.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_wcb_rate 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2012/01/04
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

String	ls_next_year

// Set the object description to be seen in messages to user
This.of_SetDescription("WCB Rate")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_wcb_rate"

// Force a new transaction for this business object
This.of_SetTransaction()

//Set primary key column
of_setpkcolumns({'book','wcb_class','tax_year'})



//Validation rules
This.of_AddValidationRule({"book"}, "REQUIRED", &
		"", "Book is Required", TRUE)
		
This.of_AddValidationRule({"wcb_class"}, "REQUIRED", &
		"", "WCB Class is Required", TRUE)		
		
This.of_AddValidationRule({"tax_year"}, "REQUIRED", &
		"", "Taxation Year is Required", TRUE)
		
This.of_AddValidationRule({"wcb_rate"}, "REQUIRED", &
		"", "Rate is Required", TRUE)	
		
This.of_AddValidationRule({"wcb_annual_maximum"}, "REQUIRED", &
		"", "Annual Maximum is Required", TRUE)			
		
This.of_AddValidationRule({"file_type"}, "REQUIRED", &
		"", "File Type is Required", TRUE)	

ls_next_year = String(Year(Today()) + 1)

This.of_AddValidationRule("tax_year", "EXPRESSION", &
		"INTEGER(<<tax_year>>) BETWEEN 1990 AND " + ls_next_year, &
		"Taxation Year Must be Between 1990 and " + ls_next_year, FALSE)		

This.of_AddValidationRule("wcb_rate", "EXPRESSION", &
		"<<wcb_rate>> BETWEEN 0 AND 15", &
		"Rate Must be Between 0 and 15", FALSE)		
		
This.of_AddValidationRule("wcb_annual_maximum", "EXPRESSION", &
		"<<wcb_annual_maximum>> BETWEEN 20000 AND 250000", &
		"Annual Maximum Must be Between 20,000 and 250,000", FALSE)				


// Default Values
This.of_setcolumndefault('wcb_annual_maximum','0')
This.of_setcolumndefault('book', trim(gnv_app.is_book))
This.of_setcolumndefault('file_type','C')
This.of_setcolumndefault('add_user_id', 		gnv_app.of_getuserid())
This.of_setcolumndefault('add_datetime', 		"TODAY" )


// Add DB Constraints
This.of_AddDBConstraint("pk_wcb_rate", "wcb_rate", "WCB_RATE","")
This.of_AddDBConstraint("fk_wcb_rate__wcb_class", "wcb_rate", "WCB Class", "wcb_class")
This.of_AddDBConstraint("fk_employee_wcb__wcb_rate", "wcb_rate", "WCB Class", "wcb_class", "Rate can't be deleted because it is referenced in an employee WCB record")

		
// Add child
of_addchild('WCB_CLASS','n_bo_wcb_class')		
end event

event bo_rowdeleted;call super::bo_rowdeleted;//************************************************************
// Object   :	n_bo_wcb_rate 
// Event    :	bo_rowdeleted
// Author   :	Lourdes Garcia
// Date     :	2012/01/06
// 	
// Arguments:	long al_row
// 	
// Returns:		(None)
// 	
// Desc:			delete wcb_class if this is the last row on the rate		
// 	
//************************************************************
// Modifications:
// Date			   Author					    Comments
//------------------------------------------------------------
//
//************************************************************
n_bo_wcb_class		lbo_wcb_class
String					ls_wcb_class
s_validation_error	lstr_error[]

ls_wcb_class = This.of_GetItemString(al_row,"wcb_class")

IF This.of_count("book = '" + gnv_app.is_book + "' and wcb_class = '" + ls_wcb_class + "'") = 1 THEN
	lbo_wcb_class = CREATE n_bo_wcb_class
	lbo_wcb_class.of_SetTransaction()


	IF lbo_wcb_class.of_retrieve("wcb_class = '" + ls_wcb_class + "'") = 1 THEN
		// delete this row too
		lbo_wcb_class.of_DeleteRow(1);
		lbo_wcb_class.of_update(TRUE,lstr_error)
	END IF
	
	DESTROY lbo_wcb_class
END IF



end event

