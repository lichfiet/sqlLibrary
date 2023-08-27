-- EVO-25798 Update Remaining Amount Based on Check History
--
-- SQL Description: This SQL is used to set the remaining amount and state of invoices to
-- paid / partially paid / not paid depending on the sum of their check history. Includes Diagnostic.
-- How to Use: Copy the SQL statement, paste it in phoenix, and replace the xxxxx with vendor number.
-- the first half is a diagnostic. Instructions are the same for the update.
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
	AND v.vendornumber = xxxxx -- Change to Vendor Number
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




-- This SQL is a drop-in replacement for output 2 on EVO-25798 when it doesn't run on larger dealerships, left in here for ease of access

--OP2
-- Resets state+remainingamt back for invoices paid w/o check V.2
UPDATE glsltransaction gls
SET sltrxstate = 1,
	remainingamt = gls.docamt
FROM (
	SELECT sltrxid
	FROM glsltransaction gls
	INNER JOIN apvendor v ON v.vendorid = gls.acctid
	LEFT JOIN apcheckinvoicelist cl ON cl.apinvoiceid = gls.sltrxid
	WHERE sltrxstate NOT IN (1, 9)
		AND v.vendornumber = 896315
		AND remainingamt <> docamt
		AND gls.accttype = 2
		AND cl.apinvoiceid IS NULL -- replaces the nested select using left join
		AND gls.description NOT ilike '%CHECK%'
		AND gls.description NOT ilike '%Void%'
	) data
WHERE gls.sltrxid = data.sltrxid;


