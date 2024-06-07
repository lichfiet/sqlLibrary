-- need to add (invoice amount = 0 if not in vendor's gl account to make it match AP Rec)
SELECT vendornumber,
	name,
	documentnumber,
 	journalentryid,
	account_number,
	debit, 
	credit,
	invoice_balance
FROM (
	SELECT sl.sltrxid,
		sl.documentnumber,
		h.journalentryid,
		coa.acctdept AS account_number,
		ROUND(amtdebit * .0001, 2) AS debit,
		ROUND(amtcredit * .0001, 2) AS credit,
		ROUND(sum(amtdebit - amtcredit) OVER (PARTITION BY scheduleidentifier) * .0001, 2) AS gl_balance,
		ROUND(sum(amtdebit - amtcredit) OVER (PARTITION BY scheduleidentifier, coa.acctdept) * .0001, 2) AS test,
		ROUND(sl.remainingamt * .0001, 2) AS invoice_balance,
		v.vendornumber,
		v.name
	FROM glhistory h
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	INNER JOIN glsltransaction sl ON sl.sltrxid = h.scheduleidentifier
	INNER JOIN apvendor v ON v.vendorid = sl.acctid
	WHERE v.vendornumber != 3241996
		AND v.vendornumber != 687522
		AND v.vendornumber != 2647
		AND v.vendornumber != 32518
	) bob
WHERE ((- 1 * invoice_balance) != gl_balance and test != 0)
    OR (gl_balance = 0 and test = 0 and invoice_balance * -1 != 0)
    
ORDER BY name, documentnumber, account_number

