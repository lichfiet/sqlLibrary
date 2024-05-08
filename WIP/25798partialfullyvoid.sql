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
