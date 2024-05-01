SELECT '$' || ROUND(sum(docamt * .0001) OVER (PARTITION BY sl.acctid), 0)::VARCHAR AS totalinvoices,
	v.name AS vendorname,
	CASE 
		WHEN badids.journalentryid IS NULL
			THEN 'N/A'
		ELSE badids.bad_ids
		END AS glfixneeded,
	sl.*
FROM glsltransaction sl
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckinvoicelist cl ON cl.apinvoiceid = sl.sltrxid
LEFT JOIN (
	SELECT h.journalentryid,
		coa.accountingid,
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
			)
	GROUP BY h.journalentryid,
		h.accountingidluid,
		coa.accountingidluid,
		h.accountingid,
		coa.accountingid,
		h.locationidluid,
		sm.childstoreidluid,
		h.locationid,
		sm.childstoreid
	) badids ON badids.journalentryid = sl.docrefglid
	AND badids.accountingid = v.accountingid
WHERE sltrxstate NOT IN (1, 9)
--	AND v.vendornumber IN (xxxxx)
	AND remainingamt <> docamt
	AND sl.accttype = 2
	AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
	AND sl.description NOT ilike '%CHECK%'
	AND sl.description NOT ilike '%Void%'
ORDER BY v.name ASC, badids.bad_ids ASC;

UPDATE glsltransaction gls
SET sltrxstate = 1,
	remainingamt = gls.docamt
FROM (
	SELECT sltrxid
	FROM glsltransaction gls
	INNER JOIN apvendor v ON v.vendorid = gls.acctid
	LEFT JOIN apcheckinvoicelist cl ON cl.apinvoiceid = gls.sltrxid
	WHERE sltrxstate NOT IN (1, 9)
--		AND v.vendornumber = 53592
		AND remainingamt <> docamt
		AND gls.accttype = 2
		AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
		AND gls.description NOT ilike '%CHECK%'
		AND gls.description NOT ilike '%Void%'
	) data
WHERE gls.sltrxid = data.sltrxid;

UPDATE glhistory h
SET accountingid = bob.acctgid,
	accountingidluid = bob.acctgidluid,
	locationid = bob.childstoreid,
	locationidluid = bob.childstoreidluid
FROM (
	SELECT s.storeid AS acctgid,
		storeidluid AS acctgidluid,
		sm.childstoreid,
		sm.childstoreidluid,
		h.glhistoryid
	FROM glhistory h
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	INNER JOIN costore s ON coa.accountingid = s.storeid
	INNER JOIN costoremap sm ON sm.parentstoreid = coa.accountingid
	WHERE (
			h.accountingidluid != coa.accountingidluid
			OR h.accountingid != coa.accountingid
			OR h.locationidluid != sm.childstoreidluid
			OR h.locationid != sm.childstoreid
			)
	) bob
WHERE bob.glhistoryid = h.glhistoryid;
