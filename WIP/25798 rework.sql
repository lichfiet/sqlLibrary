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
UPDATE glsltransaction sl
SET sl.sltrxstate = bob.newstate,
	sl.remainingamt = bob.corr_remain
FROM (
	SELECT v.name,
		/* Invoice Number */ sl.documentnumber AS invoicenumber,
		'$' || (
			0 - ROUND((
					SUM(sl.remainingamt) OVER (PARTITION BY sl.acctid) - SUM(CASE 
							WHEN voids.id IS NOT NULL
								THEN 0
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
						THEN 0
					WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0
						THEN 0
					WHEN ((docamt - sum(amtpaidthischeck))) != docamt
						THEN ROUND(((docamt - sum(amtpaidthischeck)) * .0001), 2)
					ELSE 0
					END
				)
			) AS net_invoice_adjustment,
		/* Correct Remaing Amount */
		CASE 
			WHEN voids.id IS NOT NULL
				THEN 0
			WHEN (docamt - sum(amtpaidthischeck)) <= 0
				THEN 0
			WHEN (docamt - sum(amtpaidthischeck)) != docamt
				THEN (docamt - sum(amtpaidthischeck))
			ELSE 0
			END AS corr_remain,
		/* */
		/* Invoice Description */ sl.description,
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
		OR voids.id IS NOT NULL
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
--
SELECT sltrxid
FROM glsltransaction gls
INNER JOIN apvendor v ON v.vendorid = gls.acctid
LEFT JOIN glhistory h ON h.journalentryid = gls.docrefglid
WHERE h.glhistoryid IS NULL
	AND sltrxstate IN (1, 2)
	AND v.vendornumber = 1
GROUP BY gls.sltrxid
HAVING count(distinct vendornumber) = 1
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


-- EVO-25798 Update Remaining Amount Based on Check History
--
-- SQL Description: This SQL is used to set the remaining amount and state of invoices to 
-- paid / partially paid / not paid depending on the sum of their check history
-- How to Use: Copy the SQL statement, paste it in phoenix, and click run, no modification is neccesary.
-- Jira Key/CR Number: EVO-25798 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-25798
-- SQL Statement:

/* This SQL selects everything from apcheckinvoicelist so we can calculate the total "amount paid this check" for
each invoice, where the check is not voided. This allows us to set the remaining amount to an amount equal to the
amounts paid on the checks, where they may be overpayments or items marked as paid when they shouldn't be.
It uses INNER JOINS on apvendor, and glsltransaction. The apvendor join is used to join on vendor information, which
allows us filter by vendor number. The join on glsltransaction is used to join on the invoice information itself,
which allows us to calculate remaining amount based on how much the invoic was created for, minus how much was paid.*/

-- Diagnostic // Change vendor number on line 40 to vendor with issue
SELECT /* Remaining Amount*/ ROUND((sl.remainingamt * .0001), 2) AS remaining,
	--
	/* Invoice Amount */ ROUND((sl.docamt * .0001), 2) AS docamt,
	--
	/* Paid from Checks */ ROUND(sum(amtpaidthischeck * .0001), 2) AS paidsofar,
	--
	/* Correct Remaing Amount */
	CASE 
		WHEN ((docamt - sum(amtpaidthischeck))*.0001) <= 0
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck))) != docamt
			THEN ROUND(((docamt - sum(amtpaidthischeck))* .0001), 2)
		ELSE 0
		END AS corr_remain,
	/* */
	/* Invoice Number */ sl.documentnumber,
	/* Invoice Description */ sl.description,
	--
	/* SLTRX State */
	CASE 
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0 -- If the sum of payments <= 0
			THEN 4 --FULLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
			THEN 2 -- PARTIALLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
			THEN 1 -- UNPAID
		ELSE 0 -- Panic if you get a zero
		END AS STATE,
	/* */
	sl.sltrxstate AS oldstate,
	--
	sl.sltrxid AS identifier
	--
FROM apcheckinvoicelist il
INNER JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
WHERE sltrxstate NOT IN (9)
	AND v.vendornumber = 14695 -- Change to Vendor Number
	AND ch.voidedflag = 0 -- Makes sure we don't included voided checks in the paid so far sum
GROUP BY apinvoiceid,
	sl.documentnumber,
	sl.description,
	sl.docamt,
	sl.remainingamt,
	sl.sltrxid
HAVING sum(amtpaidthischeck) != (docamt - remainingamt);

-- This sql updates the remaining amount to equal the sum of the check amounts paid against the invoice
-- The only thing that neesd to be changed is the vendor number
UPDATE glsltransaction sl
SET sltrxstate = bob.newstate,
	remainingamt = bob.corr_remain
FROM (
	SELECT
		/* Correct Remaing Amount */
		CASE 
			WHEN ((docamt - sum(amtpaidthischeck))) <= 0
				THEN 0
			WHEN (docamt - sum(amtpaidthischeck)) != docamt
				THEN (docamt - sum(amtpaidthischeck))
			ELSE 0
			END AS corr_remain,
		/* Correct SLTRX State */
		CASE 
			WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0 -- If the sum of payments <= 0
				THEN 4 --FULLY PAID
			WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
				THEN 2 -- PARTIALLY PAID
			WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
				THEN 1 -- UNPAID
			ELSE 0 -- Panic if you get a zero
			END AS newstate,
		sl.sltrxstate AS oldstate,
		sl.sltrxid AS id
	FROM apcheckinvoicelist il
	INNER JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
	INNER JOIN apvendor v ON v.vendorid = sl.acctid
	LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
	WHERE sltrxstate NOT IN (9)
		AND v.vendornumber = 14695 -- Change to Vendor Number
		AND ch.voidedflag = 0
	GROUP BY apinvoiceid,
		sl.documentnumber,
		sl.description,
		sl.docamt,
		sl.remainingamt,
		sl.sltrxid
	HAVING sum(amtpaidthischeck) != (docamt - remainingamt)
	) bob
WHERE sl.sltrxid = bob.id;

DELETE
FROM aptopayinv
WHERE aptopayinvid IN (
		SELECT aptopayinvid
		FROM aptopayinv tpi
		INNER JOIN glsltransaction sl ON sl.sltrxid = tpi.apinvoiceid
		WHERE sltrxstate IN (4, 9)
		);



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



-- EVO-17348
-- Updates invoices where all the invoices are voided but doc amt not equal remaining amount

UPDATE glsltransaction sl
SET remainingamt = docamt, -- set remaining amount = invoice amount
	sltrxstate = 1 -- set state to unpaid
FROM (
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
	) il
WHERE il.id = sl.sltrxid;




--TEST INCORPORATING BOTH

-- Diagnostic // Change vendor number on line 40 to vendor with issue
SELECT v.name,
	/* Invoice Number */ sl.documentnumber AS invoicenumber,
	'$' || (
		0 - ROUND((
				SUM(sl.remainingamt) OVER (PARTITION BY sl.acctid) - SUM(CASE 
						WHEN voids.id IS NOT NULL
							THEN 0
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
					THEN 0
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
			THEN 0
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


