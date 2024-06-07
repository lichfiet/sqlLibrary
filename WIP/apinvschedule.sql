SELECT *
FROM (
	SELECT sl.sltrxid,
		sl.documentnumber,
		h.journalentryid,
		coa.acctdept AS account_number,
		amtdebit AS debit,
		amtcredit AS credit,
		sum(amtdebit - amtcredit) OVER (PARTITION BY scheduleidentifier) AS invoice_total_gl,
		sum(amtdebit - amtcredit) OVER (
			PARTITION BY scheduleidentifier,
			coa.acctdept
			) AS invoice_total_gl_per_account,
		sum(amtdebit - amtcredit) OVER (PARTITION BY sl.acctid) AS vendor_total_gl,
		sum(amtdebit - amtcredit) OVER ( PARTITION BY sl.acctid, coa.acctdept ) AS vendor_total_gl_per_account,
		CASE 
			WHEN vt.totalvend is null
				THEN 0
			ELSE sl.remainingamt
			END AS invoice_balance,
		coalesce(vt.totalvend, 0),
		sum(amtdebit - amtcredit) OVER ( PARTITION BY sl.acctid, coa.acctdept ) + coalesce(vt.totalvend, 0) AS rec_amt,
		v.vendornumber,
		v.name
	FROM glhistory h
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	INNER JOIN glsltransaction sl ON sl.sltrxid = h.scheduleidentifier
	INNER JOIN apvendor v ON v.vendorid = sl.acctid
	LEFT JOIN glchartofaccounts vendorgl ON vendorgl.acctdeptid = v.apglacctdeptid
		AND v.apglacctdeptid != 0
	LEFT JOIN (
		SELECT sum(remainingamt) AS totalvend,
			sl.acctid
		FROM glsltransaction sl
		WHERE sl.sltrxstate IN (1, 2)
		GROUP BY sl.acctid
		) vt ON vt.acctid = sl.acctid
		AND vendorgl.acctdeptid is not null
	WHERE v.vendornumber = 2403
	) bob
--WHERE invoice_total_gl_per_account != invoice_balance * - 1
    
