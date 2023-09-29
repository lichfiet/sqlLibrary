/* TLS-648 */
/*	Output 1 - acctdeptid in glhistory not in glchartofaccounts     
	Output 2 - acctdeptid not in glbalance table     
	Output 3 - acctdeptid links to non-detail account     
	Output 4 - transaction does not balance     
	Output 5 - glhistory posted to the current earnings account     
	Output 6 - invalid acctdeptid or consacctdeptid in glconsxref table     
	Output 7 - detail account has mode different from consolidated mode     
	Output 8 - non-detail consolidating or detail consolidating to non-detail     
	Output 9 - departmentalized detail account not consolidating to consolidated department     
	Output 10 - account consolidating to more than one consolidated department account     
	Output 11 - consolidated department detail account (ie. blank department) set to consolidate     
	Output 12 - debit balance acct consolidating to credit balance acct or credit to debit     
	Output 13 - consolidation mapping has invalid acctdeptid     
	Output 14 - checks for duplicate acctdeptid     
	Output 15 - checks for duplicate consolidations*/
/*Output 1*/
SELECT 'acctdeptid in glhistory not in glchartofaccounts' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid,
	hist.amtdebit,
	hist.amtcredit
FROM glhistory hist
LEFT JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
WHERE coa.acctdeptid IS NULL;

/*Output 2*/
SELECT 'acctdeptid not in glbalance table' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid
FROM glhistory hist
INNER JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
LEFT JOIN glbalance bal ON coa.acctdeptid = bal.acctdeptid
WHERE bal.acctdeptid IS NULL;

/*Output 3*/
SELECT 'acctdeptid links to non-detail account' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	coa.acctdept,
	hist.accountingid,
	CASE 
		WHEN coa.headerdetailtotalcons = 1
			THEN 'Header'
		WHEN coa.headerdetailtotalcons = 2
			THEN 'Detail'
		WHEN coa.headerdetailtotalcons = 3
			THEN 'Total'
		WHEN coa.headerdetailtotalcons = 4
			THEN 'Consolidated'
		ELSE ''
		END AS accounttype
FROM glhistory hist,
	glchartofaccounts coa
WHERE hist.acctdeptid = coa.acctdeptid
	AND coa.headerdetailtotalcons != 2
ORDER BY hist.accountingid,
	coa.acctdept;

/*Output 4*/
SELECT 'transaction does not balance' AS description,
	journalentryid,
	accountingid,
	DATE,
	ROUND((SUM(amtdebit) * .0001), 4) AS debits,
	ROUND((SUM(amtcredit) * .0001), 4) AS credits,
	ROUND(((SUM(amtdebit) * .0001) - (SUM(amtcredit) * .0001)), 4) AS discrepancy_amt
FROM glhistory
GROUP BY journalentryid,
	accountingid,
	DATE
HAVING SUM(amtdebit) - SUM(amtcredit) != 0
ORDER BY DATE DESC;

/*Output 5*/
SELECT 'glhistory posted to the current earnings account' AS description,
	hist.glhistoryid,
	hist.journalentryid,
	hist.DATE,
	hist.acctdeptid,
	hist.amtdebit,
	hist.amtcredit,
	hist.description,
	hist.accountingid,
	hist.locationid
FROM glhistory hist,
	acpreference pref
WHERE pref.id = 'acct-CurrentEarningsAcctID'
	AND hist.acctdeptid::TEXT = pref.value
	AND hist.accountingid = pref.accountingid;

/*Output 6*/
SELECT 'invalid acctdeptid or consacctdeptid in glconsxref table' AS description,
	xref.glconsxrefid,
	xref.accountingid AS consxref_acctid,
	coa.acctdeptid AS cons_from_acct,
	coa.accountingid cons_from_acctingid,
	coa2.accountingid AS cons_to_acct,
	coa2.accountingid AS cons_to_acctingid
FROM glconsxref xref
LEFT JOIN glchartofaccounts coa ON xref.acctdeptid = coa.acctdeptid
LEFT JOIN glchartofaccounts coa2 ON xref.consacctdeptid = coa2.acctdeptid
WHERE coa.acctdeptid IS NULL
	OR coa2.acctdeptid IS NULL
	OR coa.accountingid != xref.accountingid
	OR coa2.accountingid != xref.accountingid;

/*Output 7*/
SELECT 'detail account has mode different from consolidated mode' AS description,
	glconsxrefid,
	coa.acctdept AS cons_from_acct,
	CASE 
		WHEN coa.accttype = 1
			THEN 'Asset'
		WHEN coa.accttype = 2
			THEN 'Liability'
		WHEN coa.accttype = 3
			THEN 'Revenue'
		WHEN coa.accttype = 4
			THEN 'Expense'
		WHEN coa.accttype = 5
			THEN 'Owners Equity'
		WHEN coa.accttype = 6
			THEN 'Cost Of Goods'
		ELSE ''
		END AS cons_from_mode,
	coa2.acctdept AS cons_from_acct,
	CASE 
		WHEN coa2.accttype = 1
			THEN 'Asset'
		WHEN coa2.accttype = 2
			THEN 'Liability'
		WHEN coa2.accttype = 3
			THEN 'Revenue'
		WHEN coa2.accttype = 4
			THEN 'Expense'
		WHEN coa2.accttype = 5
			THEN 'Owners Equity'
		WHEN coa2.accttype = 6
			THEN 'Cost Of Goods'
		ELSE ''
		END AS cons_from_mode
FROM glchartofaccounts coa,
	glconsxref xref,
	glchartofaccounts coa2
WHERE coa.acctdeptid = xref.acctdeptid
	AND xref.consacctdeptid = coa2.acctdeptid
	AND coa.accttype != coa2.accttype;

/*Output 8*/-- used to be 8
SELECT 'non-detail consolidating or detail consolidating to non-detail' AS description,
	coa.acctdept AS acctDept,
	CASE 
		WHEN coa.headerdetailtotalcons = 1
			THEN 'Header'
		WHEN coa.headerdetailtotalcons = 2
			THEN 'Detail'
		WHEN coa.headerdetailtotalcons = 3
			THEN 'Total'
		WHEN coa.headerdetailtotalcons = 4
			THEN 'Consolidated'
		ELSE ''
		END AS type,
	coa2.acctdept AS consAcctDept,
	CASE 
		WHEN coa2.headerdetailtotalcons = 1
			THEN 'Header'
		WHEN coa2.headerdetailtotalcons = 2
			THEN 'Detail'
		WHEN coa2.headerdetailtotalcons = 3
			THEN 'Total'
		WHEN coa2.headerdetailtotalcons = 4
			THEN 'Consolidated'
		ELSE ''
		END AS consType
FROM glconsxref xref,
	glchartofaccounts coa,
	glchartofaccounts coa2
WHERE xref.acctdeptid = coa.acctdeptid
	AND xref.consacctdeptid = coa2.acctdeptid
	AND (
		coa.headerdetailtotalcons != 2
		OR coa2.headerdetailtotalcons != 4
		);

/*Output 9*/-- used to be 9
SELECT 'departmentalized detail account not consolidating to consolidated department' AS description,
	coa.acctdept,
	coa2.acctdept AS consacctdept,
	coa.acctdeptid,
	coa2.acctdeptid AS consacctdeptid,
	coa.deptid,
	coa2.deptid AS consdeptid
FROM glconsxref xref,
	glchartofaccounts coa,
	glchartofaccounts coa2,
	gldepartment dept
WHERE xref.acctdeptid = coa.acctdeptid
	AND xref.consacctdeptid = coa2.acctdeptid
	AND coa2.deptid = dept.departmentsid
	AND dept.deptcode != '';

/*Output 10*/-- used to be 10
SELECT 'account consolidating to more than one consolidated department account' AS description,
	COUNT(coa.acctdeptid),
	coa.accountingid,
	coa.acctdeptid,
	coa.acctdept
FROM glconsxref xref
LEFT JOIN glchartofaccounts coa ON xref.acctdeptid = coa.acctdeptid
LEFT JOIN gldepartment dept ON coa.deptid = dept.departmentsid
LEFT JOIN glchartofaccounts coa2 ON xref.consacctdeptid = coa.acctdeptid
LEFT JOIN gldepartment dept2 ON coa2.deptid = dept2.departmentsid
WHERE dept2.deptcode = ''
GROUP BY coa.acctdeptid
HAVING COUNT(coa.acctdeptid) > 1
ORDER BY coa.accountingid,
	coa.acctdeptid;

/*Output 11*/-- used to be 11
SELECT 'consolidated department detail account (ie. blank department) set to consolidate' AS description,
	coa.accountingid,
	coa.acctdeptid,
	coa.acctdept AS cons_from_acct
FROM glchartofaccounts coa,
	glconsxref xref,
	gldepartment dept
WHERE coa.acctdeptid = xref.acctdeptid
	AND coa.deptid = dept.departmentsid
	AND dept.deptcode = ''
ORDER BY coa.accountingid,
	coa.acctdept;

/*Output 12*/-- used to be 12
SELECT 'debit balance acct consolidating to credit balance acct or credit to debit' AS description,
	glconsxrefid,
	a.acctdept,
	CASE 
		WHEN a.accttype = 1
			THEN 'Asset'
		WHEN a.accttype = 2
			THEN 'Liability'
		WHEN a.accttype = 3
			THEN 'Revenue'
		WHEN a.accttype = 4
			THEN 'Expense'
		WHEN a.accttype = 5
			THEN 'Owners Equity'
		WHEN a.accttype = 6
			THEN 'Cost Of Goods'
		ELSE ''
		END AS mode_,
	CASE 
		WHEN a.debitcredit = 1
			THEN 'Debit'
		WHEN a.debitcredit = 2
			THEN 'Credit'
		ELSE ''
		END AS type,
	c.acctdept AS cons_acctdept,
	CASE 
		WHEN c.accttype = 1
			THEN 'Asset'
		WHEN c.accttype = 2
			THEN 'Liability'
		WHEN c.accttype = 3
			THEN 'Revenue'
		WHEN c.accttype = 4
			THEN 'Expense'
		WHEN c.accttype = 5
			THEN 'Owners Equity'
		WHEN c.accttype = 6
			THEN 'Cost Of Goods'
		ELSE ''
		END AS cons_mode,
	CASE 
		WHEN c.debitcredit = 1
			THEN 'Debit'
		WHEN c.debitcredit = 2
			THEN 'Credit'
		ELSE ''
		END AS cons_type
FROM glchartofaccounts a,
	glconsxref b,
	glchartofaccounts c
WHERE a.acctdeptid = b.acctdeptid
	AND b.consacctdeptid = c.acctdeptid
	AND a.debitcredit != c.debitcredit;

/*glconsxref entry mapped to invalid GL Account*/-- used to be 13
SELECT 'glconsxref entry mapped to invalid GL Accoun' AS description,
	xref.glconsxrefid,
	xref.acctdeptid,
	CASE 
		WHEN det.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		ELSE 'valid COA mapping'
		END AS check_acctdeptid,
	xref.consacctdeptid,
	CASE 
		WHEN cons.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		ELSE 'valid COA mapping'
		END AS check_consacctdeptid,
	xref.accountingid
FROM glconsxref xref
LEFT JOIN glchartofaccounts det ON xref.acctdeptid = det.acctdeptid
LEFT JOIN glchartofaccounts cons ON xref.consacctdeptid = cons.acctdeptid
WHERE det.acctdeptid IS NULL
	OR cons.acctdeptid IS NULL
ORDER BY det.acctdeptid,
	cons.acctdeptid;

/*Detail Account Consolidating to More than 1 Consolidated Account*/-- used to be 14
SELECT 'Account code ' || coa.acctdept || ' has more than one consolidation' AS description,
	'(# of Consolidation): ' || COUNT(xr.acctdeptid) AS consolidation_count,
	xr.acctdeptid AS cons_acctdeptid
FROM glconsxref xr
LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = xr.acctdeptid
GROUP BY xr.acctdeptid,
	coa.acctdeptid
HAVING COUNT(xr.acctdeptid) > 1;

/*glhistory entries have an invalid ids or idluids*/
SELECT h.glhistoryid,
	CASE 
		WHEN length(h.description) > 23
			THEN left(h.description, 25) || '....'
		ELSE h.description
		END AS description,
	h.amtdebit,
	h.amtcredit,
	coa.acctdept,
	CASE 
		WHEN h.accountingid != coa.accountingid
			THEN 'accountingid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.accountingidluid != coa.accountingidluid
			THEN 'accountingidluid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.locationid != sm.childstoreid
			THEN 'locationid incorrect, '
		ELSE ''
		END || CASE 
		WHEN h.locationidluid != sm.childstoreidluid
			THEN 'locationidluid incorrect, '
		ELSE ''
		END AS bad_ids
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN costore s ON coa.accountingid = s.storeid
INNER JOIN costoremap sm ON sm.parentstoreid = coa.accountingid
INNER JOIN costore s2 ON sm.childstoreid = s2.storeid
WHERE (
		h.accountingidluid != coa.accountingidluid
		OR h.locationidluid != sm.childstoreidluid
		);
