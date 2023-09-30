/* Accounting Health Check */
/*	
    The first half of these SQLs are to pin-point setup related issues with the chart of accounts.
    
    The other half point out Product CRs or issues caused by Product CRs.
*/
/* Setup Issues */
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

/*Detail Account Consolidating to More than 1 Consolidated Account*/-- used to be 14
SELECT 'Account code ' || coa.acctdept || ' is consolidated to more than one account' AS description,
	'(# of Consolidation): ' || COUNT(xr.acctdeptid) AS consolidation_count,
	xr.acctdeptid AS cons_acctdeptid
FROM glconsxref xr
LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = xr.acctdeptid
GROUP BY xr.acctdeptid,
	coa.acctdeptid
HAVING COUNT(xr.acctdeptid) > 1;

/* DEFECTS AND PRODUCT CRs */
/*glconsxref entry mapped to invalid GL Account*/-- used to be 13 and 8 and 6
SELECT 'glconsxref entry mapped to invalid GL Account OR invalid accountingid' AS description,
	xref.glconsxrefid,
	xref.acctdeptid,
	CASE 
		WHEN det.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		WHEN det.headerdetailtotalcons != 2
			AND det.accountingid != xref.accountingid
			THEN 'NON-DETAIL ACCOUNT, ACCOUNTINGID INVALID'
		WHEN det.headerdetailtotalcons != 2
			AND det.accountingid = xref.accountingid
			THEN 'NON-DETAIL ACCOUNT'
		WHEN det.accountingid != xref.accountingid
			THEN 'ACCOUNTINGID INVALID'
		ELSE 'Valid COA Mapping'
		END AS check_acctdeptid,
	xref.consacctdeptid,
	CASE 
		WHEN cons.acctdeptid IS NULL
			THEN 'INVALID ACCTDEPTID'
		WHEN cons.headerdetailtotalcons != 4
			AND cons.accountingid != xref.accountingid
			THEN 'NON-CONSOLIDATED ACCOUNT, ACCOUNTINGID INVALID'
		WHEN cons.headerdetailtotalcons != 4
			AND cons.accountingid = xref.accountingid
			THEN 'NON-CONSOLIDATED ACCOUNT'
		WHEN cons.accountingid != xref.accountingid
			THEN 'ACCOUNTINGID INVALID'
		ELSE 'Valid COA Mapping'
		END AS check_consacctdeptid,
	xref.accountingid
FROM glconsxref xref
LEFT JOIN glchartofaccounts det ON xref.acctdeptid = det.acctdeptid
LEFT JOIN glchartofaccounts cons ON xref.consacctdeptid = cons.acctdeptid
WHERE det.acctdeptid IS NULL
	OR cons.acctdeptid IS NULL
	OR cons.headerdetailtotalcons != 4
	OR det.headerdetailtotalcons != 2
	OR cons.accountingid != xref.accountingid
	OR det.accountingid != xref.accountingid
ORDER BY det.acctdeptid,
	cons.acctdeptid;

/*glhistory entries have an invalid ids or idluids*/-- output 15
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

/*Multiple Entries in GL Balance for 1 Acctdeptid*/
SELECT 'duplicate glbalance entry for acctdeptid ' || b.acctdeptid AS description,
	coa.acctdept,
	b.fiscalyear,
	count(fiscalyear) AS num_of_duplicates
FROM glbalance b
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
GROUP BY coa.acctdept,
	b.fiscalyear,
	b.acctdeptid,
	b.storeid
HAVING count(b.fiscalyear) > 1;

/*glbalance entries with a storeid not valid with costoremap*/-- may need revision for shared accounting stores
SELECT 'gl balance entry with invalid store, check output 15 as potential cause' AS description,
	glbalancesid,
	coa.acctdept,
	b.fiscalyear
FROM glbalance b
INNER JOIN costoremap sm ON sm.parentstoreid = b.accountingid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
WHERE sm.childstoreid != b.storeid;

/*acctdeptid in glhistory not in glchartofaccounts*/
SELECT 'acctdeptid in glhistory not in glchartofaccounts' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid,
	hist.amtdebit,
	hist.amtcredit
FROM glhistory hist
LEFT JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
WHERE coa.acctdeptid IS NULL;

/*acctdeptid not in glbalance table*/
SELECT 'acctdeptid not in glbalance table' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid
FROM glhistory hist
INNER JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
LEFT JOIN glbalance bal ON coa.acctdeptid = bal.acctdeptid
WHERE bal.acctdeptid IS NULL;

/*glhistory entries tied to non-detail account*/
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

/*oob transaction*/
SELECT 'transaction does not balance' AS description,
	journalentryid,
	accountingid,
	MAX(DATE),
	ROUND((SUM(amtdebit) * .0001), 4) AS debits,
	ROUND((SUM(amtcredit) * .0001), 4) AS credits,
	ROUND(((SUM(amtdebit) * .0001) - (SUM(amtcredit) * .0001)), 4) AS discrepancy_amt,
	CASE 
		WHEN MAX(DATE) > s.conversiondate
			THEN 'may be valid'
		ELSE 'potential conversion defect'
		END AS validity
FROM glhistory h
INNER JOIN costoremap sm ON sm.parentstoreid = h.accountingid
INNER JOIN costore s ON s.storeid = sm.childstoreid
GROUP BY journalentryid,
	accountingid,
	s.conversiondate
HAVING SUM(amtdebit) - SUM(amtcredit) != 0
	AND LEFT(MAX(DATE::VARCHAR), 10) IN (
		SELECT
			LEFT(DATE::VARCHAR, 10)
		FROM glhistory h
		GROUP BY accountingid,
			LEFT(DATE::VARCHAR, 10)
		HAVING SUM(amtdebit) - SUM(amtcredit) != 0
		ORDER BY MAX(DATE) DESC
		)
ORDER BY MAX(DATE) DESC;

/*journal entry to the current earnings account*/
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
