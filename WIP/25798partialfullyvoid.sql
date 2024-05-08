/* Invoices Paid || Partially Paid || Not Paid when they shouldn't be */
--
-- This SQL diagnoses some of the issues noted in EVO-25798
-- that have to do with the remaining amounts being incorrect on
-- vendor invoices. It compares the amounts paid on 
-- checks, with the current remaining amount, and
-- will show you the increase or decrease in ap balance based on what
-- the invoice's remaining amount should be.
--
SELECT -- 
    /* Vendor */ 'Vendor: #' || v.vendornumber::varchar || ', ' || trim(v.name) AS vendor,
	/* Invoice Number */ 'Invoice #: ' || sl.documentnumber                     AS invoice_number,
	/* Invoice Amount */ '$' || ROUND((sl.docamt * .0001), 2)::varchar          AS invoice_amount,
	/* Invoice Description */ left(sl.description, 35)                          AS invoice_description,
	/* Correct Remaing Amount */
	--
	ROUND((
	CASE 
		WHEN voids.id IS NOT NULL AND docamt != 0
		    THEN docamt
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0
			THEN 0
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt 
		    THEN docamt
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0
			THEN 0
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0
			THEN docamt - sum(amtpaidthischeck)
		ELSE 0
	END
	) * .0001, 2)                                                               AS new_remaing_amount,
	/* Remaining Amount*/ ROUND((sl.remainingamt * .0001), 2)                   AS current_remaining_amount,
	/* Text Description */
	CASE
	    --
		-- IF ALL CHECKS ARE VOIDED
		WHEN voids.id IS NOT NULL
			AND docamt != 0
			THEN 'No Checks Paid'
		--
		-- IF THE SUM OF THE CHECKS = THE ORIGINAL AMOUNT, OR THE INVOICE = 0 AND THERE ARE NO CHECKS (Fully Paid)
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0
			THEN 'Sum of Payments = Original Amt OR There are no payments and Original Amt = 0'
		--
		-- IF THE SUM OF THE PAYMENTS = 0 AND THE ORIGINAL AMOUNT != 0
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0
		    THEN 'Sum of Payments = 0 And The Originbal Amount != 0'
		--
		-- IF THE SUM OF THE CHECKS ADD UP TO MORE (OR LESS IF NEGATIVE) THAN THE ORIGINAL DOCUMENT AMOUNT (Overpaid)
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) < 0
			AND docamt != 0
			THEN 'The checks paid against the invoice add up to more (or less if negative) than the original amount - Overpaid'
		--
		-- IF THE SUM OF THE CHECKS ADD UP TO LESS (OR MORE IF NEGATIVE) THAN THE ORIGINAL AMOUNT (Underpaid)
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0
			AND docamt != 0
			THEN 'The checks paid against the invoice add up to less (or more if negative) than the original amount - Underpaid'
		--
		-- EDGE CASES
		ELSE 'N/A, No Error Found'
		END                                                                     AS problem_description,
	/* Current State */ sl.sltrxstate                                           AS current_state,
	/* SLTRX State */
	CASE 
		WHEN voids.id IS NOT NULL AND docamt != 0
		    THEN 1
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0
			THEN 4
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0
			THEN 1
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0
			THEN 4
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0
			THEN 2
	END                                                                         AS new_state,
	'$' || (
		0 - ROUND((
		        --
				SUM(sl.remainingamt) OVER (PARTITION BY sl.acctid) - SUM(
				    
				    -- Determine adjustment per invoice
				    CASE 
						WHEN voids.id IS NOT NULL AND docamt != 0
							THEN docamt
						WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0
							THEN 0
						WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0
						    THEN docamt
						WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0
							THEN 0
						WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0
							THEN docamt - sum(amtpaidthischeck)
						ELSE 0
					END
					
				    ) OVER (PARTITION BY sl.acctid)
				) * .0001, 2)
		)::VARCHAR                                                              AS vendor_adjustment,
        --
        -- Invoice Adjustment Amt
		'$' || (0 - (ROUND(sl.remainingamt - (CASE 
			WHEN voids.id IS NOT NULL AND docamt != 0
				THEN (-1 * docamt)
			WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt
					THEN 0
				WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0
					THEN 0
				WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0
				    THEN docamt
				WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0
					THEN docamt - sum(amtpaidthischeck)
				ELSE 0
				END
			) * .0001, 2)))::varchar                                            AS invoice_adjustment,
	/* Paid So Far */ ROUND(sum(amtpaidthischeck * .0001), 2)                   AS sum_of_payments,
	/* SLTRX Identifier*/ coalesce(voids.id, sl.sltrxid)                        AS identifier -- If voids.id is null, then return the normal identifier
--
--
FROM apcheckinvoicelist il
RIGHT JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
LEFT JOIN (
	SELECT il.apinvoiceid AS id, -- ap invoice id or sltrxid
		sl.documentnumber
	FROM apcheckinvoicelist il -- list of invoices that have had checks paid on them
	INNER JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid -- join on checkheader to see the check states
	INNER JOIN glsltransaction sl ON sl.sltrxid = il.apinvoiceid -- join to reference the glsl info (remaining amounts and whatnot)
	WHERE sl.docamt != sl.remainingamt -- Where remaining amount != the invoice amount
		AND sltrxstate != 9 -- Not voided
		AND sl.accttype = 2 -- Is an ap invoice
	GROUP BY il.apinvoiceid,
		sl.documentnumber
	/* Whether all checks are voided */
	HAVING sum(CASE WHEN ch.voidedflag = 2 THEN 1 ELSE 0 END) = count(il.apinvoiceid)::INT
	) voids ON voids.id = sl.sltrxid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
WHERE (( sltrxstate != 9 AND ch.voidedflag = 0 ) OR voids.id IS NOT NULL ) -- Makes sure we don't included voided checks in the paid so far sum
--	AND v.vendornumber = XXXX CHANGE ME
GROUP BY apinvoiceid,
	sl.documentnumber,
	sl.description,
	sl.docamt,
	sl.remainingamt,
	sl.sltrxid,
	voids.id,
	v.name,
	v.vendornumber
HAVING (
    voids.id IS NOT NULL 
    AND docamt != 0
    AND (
		    sl.sltrxstate != 1
		    OR sl.remainingamt != docamt
		))
	OR (
	    -- fully paid
	    docamt - coalesce(sum(amtpaidthischeck), 0) = 0
	    AND (
	        sl.remainingamt != 0 
	        OR sl.sltrxstate != 4
	    ))
	OR (
	    -- Over paid
	    abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 
	    AND docamt != 0
	    AND (
	        sl.remainingamt != 0 
	        OR sl.sltrxstate != 4
	    ))
	OR (
	    -- Partially Paid
	    abs(docamt) - abs(sum(amtpaidthischeck)) > 0 
	    AND docamt != 0
	    AND (
	        sl.sltrxstate != 2 
	        OR sl.remainingamt != docamt - sum(amtpaidthischeck)
	    ))
	OR (
	    -- 0 sum payments
	    docamt - coalesce(sum(amtpaidthischeck), 0) = docamt
	    AND docamt != 0
	    AND (
	        sl.remainingamt != docamt 
	        OR sl.sltrxstate != 1
	    ));

UPDATE glsltransaction sl
SET sltrxstate = bob.new_state,
    remainingamt = bob.new_remaining_amount
FROM (
    SELECT -- 
    /* Vendor */ 'Vendor: #' || v.vendornumber::varchar || ', ' || trim(v.name) AS vendor,
	/* Invoice Number */ 'Invoice #: ' || sl.documentnumber                     AS invoice_number,
	/* Invoice Amount */ '$' || ROUND((sl.docamt * .0001), 2)::varchar          AS invoice_amount,
	/* Invoice Description */ left(sl.description, 35)                          AS invoice_description,
	/* Correct Remaing Amount */
	--
	(
	CASE 
		WHEN voids.id IS NOT NULL AND docamt != 0 THEN docamt
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0 THEN 0
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt THEN docamt
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0 THEN 0
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0 THEN docamt - sum(amtpaidthischeck)
		ELSE sl.remainingamt
	END
	)                                                                           AS new_remaining_amount,
	/* SLTRX State */
	CASE 
		WHEN voids.id IS NOT NULL AND docamt != 0 THEN 1
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = 0 THEN 4
		WHEN docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0 THEN 1
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0 THEN 4
		WHEN abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0 THEN 2
		ELSE sl.sltrxstate
	END                                                                         AS new_state,
	/* SLTRX Identifier*/ coalesce(voids.id, sl.sltrxid)                        AS identifier -- If voids.id is null, then return the normal identifier
    --
    --
    FROM apcheckinvoicelist il
    RIGHT JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
    LEFT JOIN (
    	SELECT il.apinvoiceid AS id, -- ap invoice id or sltrxid
    		sl.documentnumber
    	FROM apcheckinvoicelist il -- list of invoices that have had checks paid on them
    	INNER JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid -- join on checkheader to see the check states
    	INNER JOIN glsltransaction sl ON sl.sltrxid = il.apinvoiceid -- join to reference the glsl info (remaining amounts and whatnot)
    	WHERE sl.docamt != sl.remainingamt -- Where remaining amount != the invoice amount already
    		AND sltrxstate != 9 -- Not voided
    		AND sl.accttype = 2 -- Is an ap invoice
    	GROUP BY il.apinvoiceid,
    		sl.documentnumber
    	HAVING sum(CASE WHEN ch.voidedflag = 2 THEN 1 ELSE 0 END) = count(il.apinvoiceid)::INT
    	) voids ON voids.id = sl.sltrxid
    INNER JOIN apvendor v ON v.vendorid = sl.acctid
    LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
    WHERE (( sltrxstate != 9 AND ch.voidedflag = 0 ) OR voids.id IS NOT NULL ) -- Makes sure we don't included voided checks in the paid so far sum
    	AND v.vendornumber = 247700
    GROUP BY apinvoiceid, sl.documentnumber, sl.description,
    	sl.docamt, sl.remainingamt, sl.sltrxid, voids.id,
    	v.name, v.vendornumber
    HAVING ( voids.id IS NOT NULL AND docamt != 0 AND ( sl.sltrxstate != 1 OR sl.remainingamt != docamt )) -- checks voided
    	OR ( docamt - coalesce(sum(amtpaidthischeck), 0) = 0 AND ( sl.remainingamt != 0 OR sl.sltrxstate != 4 )) -- fully paid
    	OR ( abs(docamt) - abs(sum(amtpaidthischeck)) <= 0 AND docamt != 0 AND ( sl.remainingamt != 0 OR sl.sltrxstate != 4 )) -- Over paid
    	OR ( abs(docamt) - abs(sum(amtpaidthischeck)) > 0 AND docamt != 0 AND ( sl.sltrxstate != 2 OR sl.remainingamt != docamt - sum(amtpaidthischeck) )) -- Partially Paid
    	OR ( docamt - coalesce(sum(amtpaidthischeck), 0) = docamt AND docamt != 0 AND ( sl.remainingamt != docamt OR sl.sltrxstate != 1 )) -- 0 sum of payments
    ) bob 
WHERE bob.identifier = sl.sltrxid; 
