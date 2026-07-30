$PBExportHeader$n_bo_pr_cheque_trade_union.sru
forward
global type n_bo_pr_cheque_trade_union from n_cst_business_abio
end type
end forward

global type n_bo_pr_cheque_trade_union from n_cst_business_abio
end type
global n_bo_pr_cheque_trade_union n_bo_pr_cheque_trade_union

type variables

end variables

on n_bo_pr_cheque_trade_union.create
call super::create
end on

on n_bo_pr_cheque_trade_union.destroy
call super::destroy
end on

event constructor;call super::constructor;//************************************************************
// Object   :	n_bo_pr_cheque 
// Event    :	constructor
// Author   :	Lourdes Garcia
// Date     :	2009/05/05
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
This.of_SetDescription("PR Cheque Trade Union")

// Set the internal object's data object
This.ids_data.DataObject = "d_bo_pr_cheque_trade_union"

// Set primary key columns
This.of_SetPKColumns({"book","cheque_no", "trade_union", "union_rate_effective_date"})

// Force a new transaction for this business object
This.of_SetTransaction()	

this.of_setcolumndefault('vacation_earn', '0')
this.of_setcolumndefault('statutory_earn', '0')
this.of_setcolumndefault('reg_hour', '0')
this.of_setcolumndefault('tah_hour', '0')
this.of_setcolumndefault('ovr_hour', '0')
this.of_setcolumndefault('travel_hour', '0')
this.of_setcolumndefault('reg_earn', '0')
this.of_setcolumndefault('tah_earn', '0')
this.of_setcolumndefault('ovr_earn', '0')
this.of_setcolumndefault('travel_earn', '0')
this.of_setcolumndefault('vacation_hours_earn', '0')
this.of_setcolumndefault('union_dues', '0')
this.of_setcolumndefault('employee_rrsp', '0')
this.of_setcolumndefault('employee_pension', '0')
this.of_setcolumndefault('union_remittance', '0')
this.of_setcolumndefault('employer_rrsp', '0')
this.of_setcolumndefault('union_rrsp', '0')
this.of_setcolumndefault('union_pension', '0')
this.of_setcolumndefault('all_hr_reg_earn', '0')
this.of_setcolumndefault('all_hr_base_earn', '0')
this.of_setcolumndefault('vacation_paid_to_union', '0')
this.of_setcolumndefault('statutory_paid_to_union', '0')
this.of_setcolumndefault('vacation_source_earn', '0')
this.of_setcolumndefault('statutory_source_earn', '0')
this.of_setcolumndefault('rrsp_source_earn', '0')
this.of_setcolumndefault('pension_source_earn', '0')
this.of_setcolumndefault('dues_source_earn', '0')

This.of_AddDBConstraint("pk_pr_cheque_trade_union", 								/* constraint */ 	&
                        "trade union",													/* column */		&
								"P/R cheque trade union", 									/* message */		&
								"pr_cheque_trade_union"										/* reference table */)
This.of_AddDBConstraint("fk_pr_cheque_trade_union__book", 						/* constraint */ 	&
                        "book", 															/* column */		&
								"'book' not found in book table", 						/* message */		&
								"job"																/* reference table */)
This.of_AddDBConstraint("fk_pr_cheque_trade_union__cheque_no", 				/* constraint */ 	&
                        "cheque_no", 													/* column */		&
								"'cheque_no' not found in area table", 				/* message */		&
								"cheque_no"														/* reference table */)
This.of_AddDBConstraint("fk_pr_cheque_trade_union__trade_union", 				/* constraint */ 	&
                        "trade_union", 												/* column */		&
								"'trade_union' not found in trade_union table", 	/* message */		&
								"trade_union"													/* reference table */)

RETURN


end event

