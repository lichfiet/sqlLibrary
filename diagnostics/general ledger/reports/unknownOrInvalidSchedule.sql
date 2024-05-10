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
