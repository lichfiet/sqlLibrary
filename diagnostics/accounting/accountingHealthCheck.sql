/* Accounting Health Check 

    The first half of these SQLs are to pin-point setup related issues with the chart of accounts.
    
    The other half point out Product CRs or issues caused by Product CRs.
*/
--
/* SETUP ISSUES */
--
-- Too many or few consolidations compared to the avg for the department rounded to the nearest whole number
WITH conscounts
AS (
	SELECT sum(CASE 
				WHEN xr.acctdeptid IS NULL
					THEN 0
				ELSE 1
				END) AS conscount,
		coa.acctdept,
		coa.deptid,
		coa.acctdeptid AS HELP
	FROM glchartofaccounts coa
	LEFT JOIN glconsxref xr ON coa.acctdeptid = xr.acctdeptid
	WHERE coa.accttype IN (3, 4, 6)
	    AND coa.headerdetailtotalcons = 2
	GROUP BY coa.acctdeptid,
		coa.acctdept,
		coa.deptid
	),
deptavg
AS (
	SELECT ROUND(avg(c.conscount), 0) AS avgcount,
		c.deptid,
		d.deptcode
	FROM conscounts c
	INNER JOIN gldepartment d ON d.departmentsid = c.deptid
	GROUP BY c.deptid,
		d.deptcode
	)
SELECT 'Account # ' || cc.acctdept || ' has irregular # of consolidations for its department' AS description,
	CASE 
		WHEN cc.conscount = 0
			THEN 'Account has no consolidations'
		WHEN da.avgcount - cc.conscount < 0
			THEN 'Account has ' || ABS(da.avgcount - cc.conscount) || ' too many consolidation(s)'
		ELSE 'Account has ' || da.avgcount - cc.conscount || ' too few consolidation(s)'
		END AS tofix,
	'(# of Consolidations): ' || cc.conscount || ' , (Dept Average): ' || da.avgcount AS consolidation_count
FROM conscounts cc
INNER JOIN deptavg da ON da.deptid = cc.deptid
LEFT JOIN (
	SELECT DISTINCT acctdeptid AS accts
	FROM glhistory
	) a ON a.accts = cc.HELP
WHERE cc.conscount != da.avgcount
	AND a.accts IS NOT NULL
ORDER BY da.avgcount - cc.conscount DESC;
--
--
-- Acct In Wrong Dept (Experimentl)
WITH deptorder
AS (
	SELECT ROUND(avg(sequencenumber) OVER (PARTITION BY coa.deptid), 2) AS avgseq,
		stddev(sequencenumber) OVER (PARTITION BY coa.deptid) AS stddevseq,
		-- start dept ranks
		lag(depts.deptrank, 1) OVER (
			PARTITION BY coa.accountingid ORDER BY sequencenumber ASC
			) AS prevdept,
		depts.deptrank AS dept,
		lag(depts.deptrank, - 1) OVER (
			PARTITION BY coa.accountingid ORDER BY sequencenumber ASC
			) AS nextdept,
		-- start dept codes
		lag(deptcode, 1) OVER (
			PARTITION BY coa.accountingid ORDER BY sequencenumber ASC
			) AS prevdeptcode,
		deptcode AS deptcode,
		lag(deptcode, - 1) OVER (
			PARTITION BY coa.accountingid ORDER BY sequencenumber ASC
			) AS nextdeptcode,
		--
		coa.acctdeptid,
		coa.sequencenumber
	FROM glchartofaccounts coa
	INNER JOIN (
		SELECT coa.accountingid,
			d.deptcode,
			row_number() OVER (
				PARTITION BY coa.accountingid ORDER BY avg(sequencenumber)
				) AS deptrank,
			coa.deptid
		FROM glchartofaccounts coa
		INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
		GROUP BY coa.deptid,
			coa.accountingid,
			d.deptcode
		) depts ON depts.deptid = coa.deptid
		AND coa.accountingid = depts.accountingid
	)
SELECT coa.accountingid,
	store.stores AS store_names,
	'Account: (' || coa.acctdept || ')' AS acctnumber,
	'Seq #: ' || coa.sequencenumber::TEXT AS seqnumber,
	'Department: (' || d.deptcode || ')' AS department,
	Round(((d.sequencenumber - d.avgseq) / stddevseq), 2) AS std_deviations_from_mean,
	CASE 
		WHEN Round(((d.sequencenumber - d.avgseq) / stddevseq), 2) > 1.7
			THEN 'Account too low'
		WHEN Round(((d.sequencenumber - d.avgseq) / stddevseq), 2) < 1.7
			THEN 'Account too high'
		ELSE 'N/A'
		END AS to_fix,
	'(' || COALESCE(d.prevdeptcode::VARCHAR, 'N/A') || ', ' || COALESCE(d.deptcode::VARCHAR, 'N/A') || ', ' || COALESCE(d.nextdeptcode::VARCHAR, 'N/A') || ')' AS prevcurrnextcode,
	'(' || COALESCE(d.prevdept::VARCHAR, 'N/A') || ', ' || COALESCE(d.dept::VARCHAR, 'N/A') || ', ' || COALESCE(d.nextdept::VARCHAR, 'N/A') || ')' AS prevcurrnextrank,
	Round(d.avgseq, 2) AS avg_department_sequence,
	ROUND(d.stddevseq, 2) AS std_deviation
FROM glchartofaccounts coa
INNER JOIN deptorder d ON d.acctdeptid = coa.acctdeptid
INNER JOIN (
	SELECT CASE 
			WHEN Length(LEFT(string_agg(storename, ', '), 20)) > 17
				THEN LEFT(string_agg(storename, ', '), 20) || '...'
			ELSE LEFT(string_agg(storename, ', '), 20)
			END AS stores,
		sm.parentstoreid AS accountingid
	FROM costore s
	INNER JOIN costoremap sm ON sm.childstoreid = s.storeid
	GROUP BY sm.parentstoreid
	) store ON store.accountingid = coa.accountingid
WHERE Round((abs(d.sequencenumber - d.avgseq) / stddevseq), 2) > 2 -- where is 2 standard deviations from the mean or more
	OR (
		Round((abs(d.sequencenumber - d.avgseq) / stddevseq), 2) > 1.7 -- where is 1.7 standard deviations from the mean and account above or below is in a diff department
		AND (
			d.prevdept > d.dept
			OR d.nextdept < d.dept
			)
		);
--
-- Balance sheet account set up in a non-consolidated department
WITH deptrank
AS (
	SELECT coa.accountingid,
		d.deptcode,
		row_number() OVER (
			PARTITION BY coa.accountingid,
			coa.deptid ORDER BY avg(sequencenumber)
			) AS deptrank,
		coa.deptid
	FROM glchartofaccounts coa
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	GROUP BY coa.deptid,
		coa.accountingid,
		d.deptcode
	)
SELECT 'Balance sheet account set up in non-consolidated department' AS description,
	coa.acctdept AS account_number,
	coa.acctdesc AS account_description,
	dr.deptcode AS department_code,
	dr.deptrank AS department_order,
	coa.sequencenumber AS sequence_number
FROM glchartofaccounts coa
INNER JOIN deptrank dr ON dr.deptid = coa.deptid
WHERE dr.deptrank != 1
	AND coa.profitbalance = 1
	AND dr.deptcode NOT ilike '%lemco%';
--
-- Level greater than 9 on account (Causes COA to be unable to calculate. Numbers greater than 9 can be used but it's not advised) 
SELECT 'Account # ' || coa.acctdept || ' has a level greater than 9' as description, 
	coa.acctdeptid,
	coa.acctdept,
	coa.totallevel,
	coa.sequencenumber
FROM glchartofaccounts coa
WHERE abs(totallevel) > 9;
--
-- Account Code used multiple times, could break recalc
SELECT 'Account # ' || acctdept || ' is used ' || count(coa.acctdept) || ' times, and could cause issues recalculating'
FROM glchartofaccounts coa
GROUP BY coa.acctdept,
	coa.accountingid
HAVING count(coa.acctdept) != 1;
--
/* DEFECTS AND PRODUCT CRs */
-- glconsxref entry mapped to invalid GL Account
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

-- glhistory entries with invalid jtypeid within last 4 years / needs modification
SELECT 'glhistory entries with invalid jtypeid' AS description,
	*
FROM glhistory
LEFT JOIN gljournaltype jt ON journaltypeid = jtypeid
WHERE journaltypeid IS NULL
	AND postingdate > '2018-01-01'
ORDER BY DATE DESC LIMIT 100;

-- glhistory entries have an invalid ids or idluids // works with shared accounting
SELECT h.glhistoryid,
	CASE 
		WHEN length(h.description) > 23
			THEN left(h.description, 25) || '....'
		ELSE h.description
		END AS description,
	h.journalentryid,
	h.DATE,
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
		WHEN NOT (h.locationid = ANY (sm.storeids))
			THEN 'locationid incorrect, '
		ELSE ''
		END || CASE 
		WHEN NOT (h.locationidluid = ANY (sm.storeidluids))
			THEN 'locationidluid incorrect, '
		ELSE ''
		END AS bad_ids,
	array [h.accountingid, h.accountingidluid, h.locationid, h.locationidluid] AS acctgidsandlocationid
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN (
	SELECT string_agg(s.storename, ', ') AS stores,
		array_agg(s.storeid) AS storeids,
		array_agg(s.storeidluid) AS storeidluids,
		parentstoreid
	FROM costoremap sm
	INNER JOIN costore s ON s.storeid = sm.childstoreid
	GROUP BY parentstoreid
	) sm ON sm.parentstoreid = coa.accountingid
WHERE (
		h.accountingidluid != coa.accountingidluid
		OR h.accountingid != coa.accountingid
		OR NOT (h.locationidluid = ANY (sm.storeidluids))
		OR NOT (h.locationid = ANY (sm.storeids))
		)
ORDER BY h.DATE DESC;

-- Multiple Entries in GL Balance for 1 Acctdeptid and Fiscal Year
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

-- glbalance entries with a storeid not valid with costoremap
SELECT 'gl balance entry with invalid store, check output 4 as potential cause' AS description, -- might be diff output now
	glbalancesid,
	coa.acctdept,
	b.fiscalyear
FROM glbalance b
LEFT JOIN costoremap sm ON sm.parentstoreid = b.accountingid
	AND sm.childstoreid = b.storeid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = b.acctdeptid
WHERE sm.childstoreid IS NULL;

-- acctdeptid in glhistory not in glchartofaccounts
SELECT 'acctdeptid in glhistory but not in glchartofaccounts' AS description,
	hist.glhistoryid,
	hist.acctdeptid,
	hist.accountingid,
	hist.amtdebit,
	hist.amtcredit
FROM glhistory hist
LEFT JOIN glchartofaccounts coa ON hist.acctdeptid = coa.acctdeptid
WHERE coa.acctdeptid IS NULL;

-- acctdeptid not in glbalance table
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
WITH hist
AS (
	SELECT sum(amtdebit - amtcredit) AS storebal,
		h.journalentryid,
		locationid,
		accountingid,
		max(DATE) AS DATE
	FROM glhistory h
	WHERE jestate IN (1, 2)
	GROUP BY locationid,
		journalentryid,
		accountingid
	),
balperstore
AS (
	SELECT journalentryid,
		max(LEFT(DATE::VARCHAR, 10)) AS DATE,
		count(storebal) AS balances,
		array_agg(locationid),
		sum(storebal) AS oobsum,
		accountingid
	FROM hist
	WHERE hist.storebal != 0
	GROUP BY journalentryid,
		accountingid
	)
SELECT 'transaction does not balance' AS description,
	bps.journalentryid,
	bps.accountingid,
	DATE,
	Round((oobsum * .0001), 2) AS oob_amount,
	CASE 
		WHEN balances > 1
			AND oobsum = 0
			THEN 'Out of Balance Across Stores'
		WHEN balances > 1
			AND oobsum != 0
			THEN 'Out of Balance Individual Stores'
		WHEN balances = 1
			THEN 'Out of Balance Single Store'
		END AS bal_across_stores
FROM balperstore bps
LEFT JOIN (
	SELECT LEFT(DATE::VARCHAR, 10) AS day,
		accountingid
	FROM glhistory h
	GROUP BY accountingid,
		LEFT(DATE::VARCHAR, 10)
	HAVING SUM(amtdebit) - SUM(amtcredit) != 0
	ORDER BY MAX(DATE) DESC
	) daybalance ON daybalance.day = DATE
	AND bps.accountingid = daybalance.accountingid
WHERE (
		balances = 1
		AND daybalance.day IS NOT NULL
		)
	OR balances > 1
ORDER BY DATE DESC;

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
			THEN 'supplier code: (' || su.suppliercode || ') is missing a name'
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
		END AS recstatus,
	CASE 
		WHEN sum(h.scheddoctypeid) / count(glhistoryid) != 2
			THEN 'Missing Sched Doc Type ID from 1 or more entries'
		ELSE ''
		END AS scheddoctype
FROM glhistory h
INNER JOIN glchartofaccounts coa using (acctdeptid)
LEFT JOIN apvendor v ON v.vendorid::TEXT = h.schedacctid
LEFT JOIN costore s ON h.locationid = s.storeid
WHERE coa.schedule = 2
	AND h.isconverted = false
	AND (
		v.vendorid IS NULL
		OR h.schedacctid = ''
		)
GROUP BY h.schedacctid,
	coa.acctdept,
	s.storename,
	h.accountingid
ORDER BY SUM(amtdebit - amtcredit) DESC,
	acctdept ASC;

/* AR Rec Customer invalid will go here */

/* Deal Adjustments */
SELECT h.scheduleidentifier,
	string_agg(h.description, ', ') AS descriptions,
	Round(sum(amtdebit - amtcredit) * .0001, 2) AS bal_amt,
	CASE 
		WHEN d.dealid IS NOT NULL
			THEN 'No deal number associated to dealid/scheduleidentifier: ' || d.dealid || ', if deal is voided, un void and add a customer and dealnumber will populate'
		ELSE 'dealid/scheduleidentifier does not exist in sadeal table'
		END AS problem,
	coalesce(d.STATE::VARCHAR, 'N/A') AS dealstate,
	string_agg(b.searchname, ', ') AS nameondeal
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
LEFT JOIN sadeal d ON d.dealid = h.scheduleidentifier
	AND d.storeid = h.locationid
LEFT JOIN sadealbuyer b ON b.dealid = d.dealid
WHERE coa.acctdept = '32250'
	AND coa.schedule = 11
	AND (
		d.dealid IS NULL
		OR d.dealnumber = ''
		)
GROUP BY h.scheduleidentifier,
	d.dealid,
	b.dealid
HAVING sum(amtdebit - amtcredit) != 0;

