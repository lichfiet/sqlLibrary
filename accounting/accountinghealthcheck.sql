/* Accounting Health Check */
/*	
    The first half of these SQLs are to pin-point setup related issues with the chart of accounts.
    
    The other half point out Product CRs or issues caused by Product CRs.
*/
/* SETUP ISSUES */
/*Detail Account Consolidating to More than 1 Consolidated Account*/-- used to be 14
SELECT 'Account code ' || coa.acctdept || ' is consolidated to more than one account' AS description,
	'(# of Consolidation): ' || COUNT(xr.acctdeptid) AS consolidation_count,
	xr.acctdeptid AS cons_acctdeptid
FROM glconsxref xr
LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = xr.acctdeptid
GROUP BY xr.acctdeptid,
	coa.acctdeptid
HAVING COUNT(xr.acctdeptid) > 1;

/* Less than 2 consolidations for P&L Accounts

SELECT 'Account code ' || coa.acctdept || ' is a detail account, consolidated to less than one account' AS description,
	'(# of Consolidation): ' || COUNT(xr.acctdeptid) AS consolidation_count,
	xr.acctdeptid AS cons_acctdeptid
FROM glconsxref xr
LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = xr.acctdeptid
WHERE coa.accttype IN (3, 4, 6)
    AND consind = 0
GROUP BY xr.acctdeptid,
	coa.acctdeptid
HAVING COUNT(xr.acctdeptid) < 2
ORDER BY COUNT(xr.acctdeptid) DESC
*/

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

/*glhistory entries with invalid jtypeid within last 4 years*/-- needs modification
SELECT *
FROM glhistory
LEFT JOIN gljournaltype jt ON journaltypeid = jtypeid
WHERE journaltypeid IS NULL
	AND postingdate > '2018-01-01'
ORDER BY DATE DESC;

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
INNER JOIN costoremap sm ON sm.parentstoreid = coa.accountingid
WHERE (
		h.accountingidluid != coa.accountingidluid
		OR h.accountingid != coa.accountingid
		OR h.locationidluid != sm.childstoreidluid
		OR h.locationid != sm.childstoreid
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

/*glbalance entries with a storeid not valid with costoremap*/
SELECT 'gl balance entry with invalid store, check output 4 as potential cause' AS description,
	glbalancesid,
	coa.acctdept,
	b.fiscalyear
FROM glbalance b
LEFT JOIN costoremap sm ON sm.parentstoreid = b.accountingid
	AND sm.childstoreid = b.storeid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
WHERE sm.childstoreid IS NULL;

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
SELECT 'acctdeptid links to non-detail account in glhistory' AS description,
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
		SELECT LEFT(DATE::VARCHAR, 10)
		FROM glhistory h
		GROUP BY accountingid,
			LEFT(DATE::VARCHAR, 10)
		HAVING SUM(amtdebit) - SUM(amtcredit) != 0
		ORDER BY MAX(DATE) DESC
		)
ORDER BY MAX(DATE) DESC;

/* day does not balance */
SELECT 'day does not balance' AS description,
	SUM(amtdebit) - SUM(amtcredit) AS oob_amount,
	LEFT(DATE::VARCHAR, 10),
	h.accountingid
FROM glhistory h
GROUP BY accountingid,
	LEFT(DATE::VARCHAR, 10)
HAVING SUM(amtdebit) - SUM(amtcredit) != 0
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

/*Unknown Unit on Major Unit Reconciliation / Invalid Schedule Identifier*/
SELECT 'Unknown Unit for Account Number #' || coa.acctdept AS glaccountnumber,
	h.scheduleidentifier AS muid,
	h.acctdeptid,
	SUM(amtdebit - amtcredit)::FLOAT / 10000 AS outofbalanceamt,
	s.storecode,
	s.storename
FROM glhistory h
LEFT JOIN samajorunit mu ON h.scheduleidentifier = mu.majorunitid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN costore s ON s.storeidluid = h.locationidluid
WHERE coa.schedule = 4
	AND mu.majorunitid IS NULL
GROUP BY h.scheduleidentifier,
	h.acctdeptid,
	h.locationid,
	s.storename,
	coa.acctdept,
	s.storecode
ORDER BY (
		CASE 
			WHEN SUM(amtdebit - amtcredit) != 0
				THEN 1
			ELSE 0
			END
		),
	SUM(amtdebit - amtcredit)::FLOAT / 10000 DESC;

/*Unknown Supplier on GL Schedules Report*/
SELECT 'unknown supplier' AS description,
	CASE 
		WHEN ps.partshipmentid IS NULL
			THEN 'invalid partshipmentid or storeid'
		WHEN (
				su.suppliername IS NULL
				OR su.suppliername = ''
				)
			THEN 'supplier ' || su.suppliercode || ' missing suppliername'
		ELSE 'unknown error'
		END AS issuedescription,
	h.journalentryid AS transactionnumber,
	h.documentnumber,
	CASE 
		WHEN length(h.description) > 23
			THEN LEFT(h.description, 25) || '...'
		ELSE h.description
		END AS description,
	((h.amtdebit - h.amtcredit) * .0001) AS amount,
	h.DATE,
	s.storecode,
	ps.packingslip,
	h.glhistoryid
FROM glhistory h
INNER JOIN (
	SELECT sum(amtdebit),
		sum(amtcredit),
		(sum(amtdebit) - sum(amtcredit)) AS dif,
		scheduleidentifier,
		coa.acctdeptid
	FROM glhistory h
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	WHERE coa.schedule = 12
	GROUP BY scheduleidentifier,
		coa.acctdeptid
	HAVING (sum(amtdebit) - sum(amtcredit)) != 0
	) rpt ON rpt.scheduleidentifier = h.scheduleidentifier
	AND rpt.acctdeptid = h.acctdeptid
LEFT JOIN papartshipment ps ON ps.partshipmentid = h.scheduleidentifier
	AND ps.storeid = h.locationid
	AND ps.storeidluid = h.locationidluid
LEFT JOIN pasupplier su ON ps.supplierid = su.supplierid
LEFT JOIN costore s ON s.storeid = h.locationid
WHERE (
		ps.partshipmentid IS NULL
		OR su.suppliername = ''
		OR su.suppliername IS NULL
		)
ORDER BY h.scheduleidentifier;

/*Vendor Invalid on AP Reconciliation / Invalid schedacctid tying to vendorid*/
SELECT 'Vendor Invalid on AP Rec' AS description,
	s.storename,
	coa.acctdept AS accountnumber,
	schedacctid,
	SUM(amtdebit - amtcredit)::FLOAT / 10000 AS outofbalanceamt,
	CASE 
		WHEN SUM(amtdebit - amtcredit) = 0
			THEN 'Not on AP Rec'
		ELSE 'On AP Rec'
		END AS recstatus
FROM glhistory h
INNER JOIN glchartofaccounts coa using (acctdeptid)
LEFT JOIN apvendor v ON v.vendorid::TEXT = h.schedacctid
INNER JOIN costore s ON h.locationid = s.storeid
WHERE h.scheddoctypeid = 2
	AND h.isconverted = false
	AND v.vendorid IS NULL
GROUP BY h.schedacctid,
	coa.acctdept,
	s.storename
ORDER BY SUM(amtdebit - amtcredit) DESC,
	acctdept ASC;
	/* AR Rec Cut invalid will go here */
