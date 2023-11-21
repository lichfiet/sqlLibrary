/* Accounts Payable Health Check */
--
-- Info: This SQL will diagnose some common issues relating to CRs and other
-- related issues caused by bugs. It also includes some info about things like
-- the ap reconciliation.
--
-- To use: By default will select for all vendors, will make a single vendor one
-- at some point.
-- 
-- Outputs:
--
--  1) Invoices Paid/Partially Paid/Not Paid
--  2) Invoices Paid with no check history
--  3) Store and Accounting Comparison vs glsl, coa, and glhist
--  4) aptopayinv items linking to bad glsl data
-- 
/* Invoices Paid/Partially Paid/Not Paid when they shouldn't be */
--
-- This SQL diagnoses some of the issues noted in EVO-25798
-- that have to do with the remaining amounts being incorrect on
-- vendor invoices. It compares the amounts paid on 
-- checks, with the current remaining amount, and
-- will show you the increase or decrease in ap balance based on what
-- the invoice's remaining amount should be.
--
SELECT v.name,
	/* Invoice Number */ sl.documentnumber AS invoicenumber,
	'$' || (
		0 - ROUND((
				SUM(sl.remainingamt) OVER (PARTITION BY sl.acctid) - SUM(CASE 
						WHEN voids.id IS NOT NULL
							THEN docamt
						WHEN (docamt - sum(amtpaidthischeck)) <= 0
							THEN 0
						WHEN (docamt - sum(amtpaidthischeck)) != docamt
							THEN (docamt - sum(amtpaidthischeck))
						ELSE 0
						END) OVER (PARTITION BY sl.acctid)
				) * .0001, 2)
		)::VARCHAR AS net_vendor_adjustment,
	/* Net Adjustment Amount */ (
		0 - (
			ROUND((sl.remainingamt * .0001), 2) - CASE 
				WHEN voids.id IS NOT NULL
					THEN ROUND((docamt * .0001), 2)
				WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0
					THEN 0
				WHEN ((docamt - sum(amtpaidthischeck))) != docamt
					THEN ROUND(((docamt - sum(amtpaidthischeck)) * .0001), 2)
				ELSE 0
				END
			)
		) AS net_invoice_adjustment,
	/* Remaining Amount*/ ROUND((sl.remainingamt * .0001), 2) AS current_remaining_amt,
	--
	/* Invoice Amount */ ROUND((sl.docamt * .0001), 2) AS invoice_amount,
	--
	/* Paid from Checks */ ROUND(sum(amtpaidthischeck * .0001), 2) AS sum_of_payments,
	--
	/* Correct Remaing Amount */
	CASE 
		WHEN voids.id IS NOT NULL
			THEN ROUND((docamt * .0001),2)
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck))) != docamt
			THEN ROUND(((docamt - sum(amtpaidthischeck)) * .0001), 2)
		ELSE 0
		END AS corr_remain,
	/* */
	/* Invoice Description */ sl.description,
	--
	/* SLTRX State */
	CASE 
		WHEN voids.id IS NOT NULL -- if part of the voided checks list
			THEN 1
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0 -- If the sum of payments <= 0
			THEN 4 --FULLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
			THEN 2 -- PARTIALLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
			THEN 1 -- UNPAID
		ELSE 0 -- Panic if you get a zero
		END AS newstate,
	/* */
	/* Current State */ sl.sltrxstate AS oldstate,
	/* Text Description */
	CASE 
		WHEN voids.id IS NOT NULL -- if part of the voided checks list
			THEN 'No Checks Paid'
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = 0
			THEN 'Sum of Payments = 0'
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) < 0 -- If the sum of payments <= 0
			THEN 'Sum of Payments < 0 - Overpaid' --FULLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
			THEN 'Sum of Payments != docamt, partially paid' -- PARTIALLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
			THEN 'Sum of Payments = 0 pt. 2' -- UNPAID
		ELSE 'N/A' -- Panic if you get a zero
		END AS change,
	/* */
	--
	CASE 
		WHEN voids.id IS NOT NULL
			THEN voids.id
		ELSE sl.sltrxid
		END AS identifier
--
FROM apcheckinvoicelist il
LEFT JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
LEFT JOIN (
	SELECT il.apinvoiceid AS id, -- ap invoice id or sltrxid
		sl.documentnumber
	FROM apcheckinvoicelist il -- list of invoices that have had checks paid on them
	INNER JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid -- join on checkheader to see the check states
	INNER JOIN glsltransaction sl ON sl.sltrxid = il.apinvoiceid -- join to reference the glsl info (remaining amounts and whatnot)
	WHERE sl.docamt != sl.remainingamt -- Where remaining amount != the invoice amount
		AND sltrxstate NOT IN (9, 4) -- Not voided or already paid
		AND sl.accttype = 2 -- Is an ap invoice
	GROUP BY il.apinvoiceid,
		sl.documentnumber
	/* Whether all checks are voided */
	HAVING sum(CASE 
				WHEN ch.voidedflag = 2
					THEN 1
				ELSE 0
				END) = count(il.apinvoiceid)::INT
	) voids ON voids.id = sl.sltrxid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
WHERE (
		(
			sltrxstate NOT IN (9)
			AND ch.voidedflag = 0
			)
		OR voids.id IS NOT NULL
		)
--	AND v.vendornumber = 410928 -- Makes sure we don't included voided checks in the paid so far sum
GROUP BY apinvoiceid,
	sl.documentnumber,
	sl.description,
	sl.docamt,
	sl.remainingamt,
	sl.sltrxid,
	voids.id,
	v.name
HAVING sum(amtpaidthischeck) != (docamt - remainingamt)
	OR voids.id IS NOT NULL;

-- Output 2
SELECT '$' || (ROUND(sum(docamt * .0001) OVER (PARTITION BY sl.acctid), 0))::VARCHAR AS total_invoice_adjustment,
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
	LEFT JOIN glsltransaction sl ON sl.sltrxid = h.schedxrefid
	LEFT JOIN apvendor v ON v.vendorid = sl.acctid
	LEFT JOIN costoremap smv on smv.parentstoreid = v.accountingid
	WHERE (
			h.accountingidluid != coa.accountingidluid
			OR h.accountingid != coa.accountingid
			OR h.locationidluid != sm.childstoreidluid
			OR h.locationid != sm.childstoreid
			OR (
				sl.sltrxid IS NOT NULL
				AND sl.accountingid = smv.parentstoreid
				AND (
					sl.storeid != h.locationid
					OR sl.storeidluid != h.locationidluid
					OR sl.accountingid != h.accountingid
					OR sl.accountingid != sl.accountingidluid
					)
				)
			OR sl.accountingid != v.accountingid
			OR sl.storeid != smv.childstoreid
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
	--	AND v.vendornumber IN (xxxxxx)
	AND remainingamt <> docamt
	AND sl.accttype = 2
	AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
	AND sl.description NOT ilike '%CHECK%'
	AND sl.description NOT ilike '%Void%'
ORDER BY v.name ASC,
	badids.bad_ids ASC;

-- oyutput 3 ids
SELECT v.name AS vendor_name,
	sl.documentnumber AS invoicenumber,
	TO_CHAR(sl.DATE, 'YYYY-MM-DD') as invoice_date,
	'$' || ROUND((sl.docamt * .0001), 2)::VARCHAR AS invoice_amount,
	/* glhistory vs chart of accounts*/
    'COA is correct' || CASE 
		WHEN h.accountingid != coa.accountingid
			THEN 'accountingid, '
		ELSE ''
		END || CASE 
		WHEN h.accountingidluid != coa.accountingidluid
			THEN 'accountingidluid, '
		ELSE ''
		END || CASE 
		WHEN h.locationid != sm.childstoreid
			THEN 'storeid, '
		ELSE ''
		END || CASE 
		WHEN h.locationidluid != sm.childstoreidluid
			THEN 'storeidluid  '
		ELSE ''
		END AS chartofaccountsvsglhistory,
	/* */
	CASE 
		WHEN sl.accountingid != v.accountingid
			THEN 'accountingid, '
		ELSE ''
		END || CASE 
		WHEN sl.accountingidluid != v.accountingidluid
			THEN 'accountingidluid, '
		ELSE ''
		END || CASE 
		WHEN sl.storeid != smv.childstoreid
			THEN 'storeid, '
		ELSE ''
		END || CASE 
		WHEN sl.storeidluid != smv.childstoreidluid
			THEN 'storeidluid, '
		ELSE ''
		END AS glslvsvendor,
	CASE 
		WHEN sl.accountingid != h.accountingid
			THEN 'accountingid, '
		ELSE ''
		END || CASE 
		WHEN sl.accountingidluid != h.accountingidluid
			THEN 'accountingidluid, '
		ELSE ''
		END || CASE 
		WHEN sl.storeid != h.locationid
			THEN 'storeid, '
		ELSE ''
		END || CASE 
		WHEN sl.storeidluid != h.locationidluid
			THEN 'storeidluid, '
		ELSE ''
		END AS glslvsglhistory,
	sl.sltrxid AS glsl_id,
	h.glhistoryid AS history_id,
	v.vendorid AS vendor_id,
	coa.acctdeptid AS account_id,
	'GLSL IDs [' || 'acctg: ' || sl.accountingid::varchar || ', ' || sl.accountingidluid::varchar || ' storeids: ' || sl.storeid::varchar || ', ' || sl.storeidluid::varchar || ']',
	h.locationid
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN costoremap sm ON sm.parentstoreid = coa.accountingid
INNER JOIN glsltransaction sl ON sl.sltrxid = h.schedxrefid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
INNER JOIN costoremap smv ON smv.parentstoreid = v.accountingid
WHERE (
		h.accountingidluid != coa.accountingidluid
		OR h.accountingid != coa.accountingid
		OR h.locationidluid != sm.childstoreidluid
		OR h.locationid != sm.childstoreid
		)
	OR (
		sl.storeid != smv.childstoreid
		OR sl.storeidluid != smv.childstoreidluid
		OR sl.accountingid != v.accountingid
		OR sl.accountingidluid != v.accountingidluid
		)
	OR (
		sl.accountingid != h.accountingid
		OR sl.accountingidluid != h.accountingidluid
		OR sl.storeid != h.locationid
		OR sl.storeidluid != h.locationidluid
		);

-- output 4

SELECT v.name,
	sl.documentnumber AS invoicenumber,
	sl.*
FROM aptopayinv tpi
LEFT JOIN glsltransaction sl ON sl.sltrxid = tpi.apinvoiceid
LEFT JOIN apvendor v ON v.vendorid = tpi.vendorid
WHERE sl.sltrxid IS NULL
	OR sl.sltrxstate NOT IN (1, 2);

