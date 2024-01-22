--
--
-- 8888888888 888     888  .d88888b.          .d8888b.  888888888 8888888888  .d8888b.   .d8888b. 
-- 888        888     888 d88P" "Y88b        d88P  Y88b 888             d88P d88P  Y88b d88P  Y88b
-- 888        888     888 888     888               888 888            d88P  888    888 Y88b. d88P
-- 8888888    Y88b   d88P 888     888             .d88P 8888888b.     d88P   Y88b. d888  "Y88888" 
-- 888         Y88b d88P  888     888         .od888P"       "Y88b 88888888   "Y888P888 .d8P""Y8b.
-- 888          Y88o88P   888     888 888888 d88P"             888  d88P            888 888    888
-- 888           Y888P    Y88b. .d88P        888"       Y88b  d88P d88P      Y88b  d88P Y88b  d88P
-- 8888888888     Y8P      "Y88888P"         888888888   "Y8888P" d88P        "Y8888P"   "Y8888P" 
--
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--  
-- This SQL is used to diagnose common problems and issues relating to and caused by EVO-25798. 
-- 
-- It includes multiple diagnostics in this order:
--
--      Output 1: 
--	Incorrect Storeid / Accountingid or luids
--
--      Output 2:
--	Checks paid, partially paid, and not paid when they should be.
--      This includes checks where all invoices were voided
--	
--	Output 3: 
--	Checks marked as paid with no invoice history due 
--	to glhistory entries with no or bad storeid fields
--       
--
--
--
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         d888  
-- d88P" "Y88b          888                      888        d8888  
-- 888     888          888                      888          888  
-- 888     888 888  888 888888 88888b.  888  888 888888       888  
-- 888     888 888  888 888    888 "88b 888  888 888          888  
-- 888     888 888  888 888    888  888 888  888 888          888  
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.        888  
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888     8888888
--                             888                                 
--                             888                                 
--                             888                                 
--                                                                                                                                                                        
--
--
--  Corrects erroneous packing slip invoice, storeid = 0
--
--
UPDATE glsltransaction gls
SET storeid = ${Storeid invoices originated in},
	storeidluid = data.good_id
FROM (
	SELECT gls.sltrxid,
		gls.storeid,
		s.storeidluid AS good_id
	FROM glsltransaction gls
	INNER JOIN costore s USING (storeid)
	WHERE s.storeid = ${Storeid invoices originated in}
	) data
WHERE gls.storeid = 0
	AND accttype = 2;
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         .d8888b. 
-- d88P" "Y88b          888                      888        d88P  Y88b
-- 888     888          888                      888               888
-- 888     888 888  888 888888 88888b.  888  888 888888          .d88P
-- 888     888 888  888 888    888 "88b 888  888 888         .od888P" 
-- 888     888 888  888 888    888  888 888  888 888        d88P"     
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.      888"      
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888     888888888 
--                             888                                    
--                             888                                    
--                             888                                    
--
-- Updates remaining amount and state for invoices over/under/not paid
--
UPDATE glsltransaction sl
SET sltrxstate = bob.newstate,
	remainingamt = bob.corr_remain
FROM (
	SELECT v.name,
		/* Invoice Number */ sl.documentnumber AS invoicenumber,
		/* Correct Remaing Amount */
		CASE 
			WHEN voids.id IS NOT NULL
				AND docamt != 0
				THEN docamt
			WHEN (docamt - sum(amtpaidthischeck)) <= 0
				AND docamt != 0
				THEN 0
			WHEN (docamt - sum(amtpaidthischeck)) != docamt
				AND docamt != 0
				THEN (docamt - sum(amtpaidthischeck))
			WHEN docamt = 0
				THEN 0
			ELSE 0
			END AS corr_remain,
		/* */
		/* SLTRX State */
		CASE 
			WHEN voids.id IS NOT NULL
				AND docamt != 0 -- if part of the voided checks list
				THEN 1
			WHEN ((docamt - sum(amtpaidthischeck))) <= 0
				AND docamt != 0 -- If the sum of payments <= 0
				THEN 4 --FULLY PAID
			WHEN ((docamt - sum(amtpaidthischeck))) != docamt
				AND docamt != 0 -- If the sum of payments = part of the invoice amt
				THEN 2 -- PARTIALLY PAID
			WHEN ((docamt - sum(amtpaidthischeck))) = docamt
				AND docamt != 0 --- IF the sum of check payments = 0
				THEN 1 -- UNPAID
			WHEN docamt = 0 -- invoiceamt = 0
				THEN 4
			ELSE 0 -- Panic if you get a zero
			END AS newstate,
		/* */
		/* sltrxid (needed for the left join on voids)*/
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
		AND v.vendornumber = 528066
	GROUP BY apinvoiceid,
		sl.documentnumber,
		sl.description,
		sl.docamt,
		sl.remainingamt,
		sl.sltrxid,
		voids.id,
		v.name
	HAVING sum(amtpaidthischeck) != (docamt - remainingamt)
		OR voids.id IS NOT NULL
		OR sl.sltrxstate != (
			CASE 
				WHEN voids.id IS NOT NULL
					AND docamt != 0 -- if part of the voided checks list
					THEN 1
				WHEN ((docamt - sum(amtpaidthischeck))) <= 0
					AND docamt != 0 -- If the sum of payments <= 0
					THEN 4 --FULLY PAID
				WHEN ((docamt - sum(amtpaidthischeck))) != docamt
					AND docamt != 0 -- If the sum of payments = part of the invoice amt
					THEN 2 -- PARTIALLY PAID
				WHEN ((docamt - sum(amtpaidthischeck))) = docamt
					AND docamt != 0 --- IF the sum of check payments = 0
					THEN 1 -- UNPAID
				WHEN docamt = 0 -- invoiceamt = 0
					THEN 4
				ELSE 0 -- Panic if you get a zero
				END
			)
	) bob
WHERE sl.sltrxid = bob.identifier;
--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888         .d8888b. 
-- d88P" "Y88b          888                      888        d88P  Y88b
-- 888     888          888                      888             .d88P
-- 888     888 888  888 888888 88888b.  888  888 888888         8888" 
-- 888     888 888  888 888    888 "88b 888  888 888             "Y8b.
-- 888     888 888  888 888    888  888 888  888 888        888    888
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.      Y88b  d88P
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888      "Y8888P" 
--                             888                                    
--                             888                                    
--                             888                                    
--
-- Voids Invoice with No GL History Info
--
UPDATE glsltransaction sl
SET sltrxstate = 9
FROM (
	SELECT sltrxid
	FROM glsltransaction gls
	INNER JOIN apvendor v ON v.vendorid = gls.acctid
	LEFT JOIN glhistory h ON h.journalentryid = gls.docrefglid
	WHERE h.glhistoryid IS NULL
		AND sltrxstate IN (1, 2)
		AND v.vendornumber = 1
	GROUP BY gls.sltrxid
	HAVING count(distinct vendornumber) = 1
) bob
WHERE bob.sltrxid = sl.sltrxid

--
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--
--
--  .d88888b.           888                      888            d8888 
-- d88P" "Y88b          888                      888           d8P888 
-- 888     888          888                      888          d8P 888 
-- 888     888 888  888 888888 88888b.  888  888 888888      d8P  888 
-- 888     888 888  888 888    888 "88b 888  888 888        d88   888 
-- 888     888 888  888 888    888  888 888  888 888        8888888888
-- Y88b. .d88P Y88b 888 Y88b.  888 d88P Y88b 888 Y88b.            888 
--  "Y88888P"   "Y88888  "Y888 88888P"   "Y88888  "Y888           888 
--                             888                                    
--                             888                                    
--                             888                                    
--
SELECT ps.partshipmentid
FROM glsltransaction gls
INNER JOIN apvendor v ON v.vendorid = gls.acctid
INNER JOIN papartshipment ps ON ps.apinvoiceid = gls.sltrxid
LEFT JOIN glhistory h ON h.journalentryid = gls.docrefglid
WHERE h.glhistoryid IS NULL
	AND sltrxstate = 9
	AND v.vendornumber = 1
GROUP BY ps.partshipmentid
HAVING count(DISTINCT vendornumber) = 1


DELETE
FROM aptopayinvoice
WHERE aptopayinvid IN (
		SELECT tpi.aptopayinvid
		FROM aptopayinv tpi
		LEFT JOIN glsltransaction sl ON sl.sltrxid = tpi.apinvoiceid
		LEFT JOIN apvendor v ON v.vendorid = sl.acctid
		WHERE sl.sltrxid IS NULL
			OR sl.sltrxstate IN (9, 4)
			OR v.vendorid IS NULL
		)
--
-- Output 5
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



-- This SQL is a drop-in replacement for output 2 on EVO-25798 when it doesn't run on larger dealerships, left in here for ease of access

--OP2
-- Resets state+remainingamt back for invoices paid w/o check V.2

-- Output 2 diagnostic
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
--	AND v.vendornumber IN ()
	AND remainingamt <> docamt
	AND sl.accttype = 2
	AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
	AND sl.description NOT ilike '%CHECK%'
	AND sl.description NOT ilike '%Void%'
ORDER BY v.name ASC, badids.bad_ids ASC

-- Output 2 updates
UPDATE glsltransaction sl
SET sltrxstate = 1,
	remainingamt = sl.docamt
FROM (
	SELECT '$' || ROUND(sum(docamt * .0001) OVER (PARTITION BY sl.acctid), 0)::VARCHAR AS totalinvoices,
	    v.name as vendorname,
		sl.*
	FROM glsltransaction sl
	INNER JOIN apvendor v ON v.vendorid = sl.acctid
	LEFT JOIN apcheckinvoicelist cl ON cl.apinvoiceid = sl.sltrxid
	WHERE sltrxstate NOT IN (1, 9)
		AND v.vendornumber IN (27968, 28122)
		AND remainingamt <> docamt
		AND sl.accttype = 2
		AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
		AND sl.description NOT ilike '%CHECK%'
		AND sl.description NOT ilike '%Void%'
	) data
WHERE sl.sltrxid = data.sltrxid;

UPDATE glhistory h
SET accountingid = bob.acctgid,
	accountingidluid = bob.acctgidluid,
	locationid = bob.childstoreid,
	locationidluid = bob.childstoreidluid
FROM (
	SELECT s.storeid AS acctgid,
		storeidluid AS acctgidluid,
		sm.childstoreid,
		h.journalentryid,
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



