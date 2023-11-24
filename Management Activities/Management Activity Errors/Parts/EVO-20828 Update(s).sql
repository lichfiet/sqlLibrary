-- EVO-20828 List of Updates that may or may not work
--
-- SQL Description: this is just a list of potential updates to use on 20828 related issues 
-- How to Use: Copy the SQL statement, and modify based on comments above the SQL
-- Jira Key/CR Number: EVO-20828 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-20828
-- SQL Statement:

-- EXPERIMENTAL UPDATE WITH DIAG PLEASE USE, Need to add a join to eliminate non-pay part invoices because they show the same output with the diag
UPDATE papartinvoiceline pil
SET adjustmentprice = adjustmentprice + bob.adjamt,
	islinediscount = 1
FROM (
	SELECT partinvoicelineid,
		row_Number() OVER (
			PARTITION BY partinvoiceid ORDER BY qtysold DESC,
				qtyspecialorder DESC
			),
		sum(debitamt) OVER (PARTITION BY partinvoiceid) AS debits,
		sum(creditamt) OVER (PARTITION BY partinvoiceid) AS credits,
		sum(debitamt - creditamt) OVER (PARTITION BY partinvoiceid) AS OOB_Amount,
		(
			Round(sum(debitamt - creditamt) OVER (PARTITION BY partinvoiceid) / (
					CASE 
						WHEN qtysold != 0
							THEN qtysold
						ELSE qtyspecialorder
						END
					), 4) * 10000
			)::INTEGER AS adjamt
	FROM papartinvoiceline pil
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	INNER JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	INNER JOIN (
		SELECT businessactionid
		FROM (
			SELECT ba.businessactionid
			FROM papartinvoiceline pi
			INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
			INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = pi.partinvoiceid
			INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
			INNER JOIN mabusinessaction ba ON ba.documentid = pi.partinvoiceid
			INNER JOIN (
				SELECT pi.partinvoiceid
				FROM papartinvoice pi
				INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
				INNER JOIN (
					SELECT SUM((qtyspecialorder * adjustmentprice) / 10000) AS amt,
						partinvoiceid
					FROM papartinvoiceline
					GROUP BY partinvoiceid
					) soamt ON soamt.partinvoiceid = pi.partinvoiceid
				WHERE pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
				) v1 ON v1.partinvoiceid = pi.partinvoiceid
			INNER JOIN (
				SELECT SUM(debitamt - creditamt) AS oob,
					bai.businessactionid
				FROM mabusinessactionitem bai
				INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
				WHERE ba.documenttype = 1001
					AND ba.STATUS = 2
				GROUP BY bai.businessactionid
				) oob ON oob.businessactionid = ba.businessactionid
			INNER JOIN (
				SELECT SUM(depositapplied) AS applied,
					partinvoiceid
				FROM papartinvoiceline
				GROUP BY partinvoiceid
				) dep ON dep.partinvoiceid = pi.partinvoiceid
			INNER JOIN (
				SELECT pi.partinvoiceid
				FROM papartinvoice pi
				INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
				INNER JOIN (
					SELECT sum((qtyspecialorder * adjustmentprice) / 10000) AS amt,
						partinvoiceid
					FROM papartinvoiceline
					GROUP BY partinvoiceid
					) soamt ON soamt.partinvoiceid = pi.partinvoiceid
					AND pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
				) soa ON soa.partinvoiceid = pi.partinvoiceid
			WHERE ba.documenttype = 1001
				AND ba.STATUS = 2
				AND dep.applied <> oob.oob
			GROUP BY ba.businessactionid
			) data
		GROUP BY businessactionid
		) diag ON diag.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
	) bob
WHERE bob.partinvoicelineid = pil.partinvoicelineid
	AND row_number = 1;




-- DONT USE THESE SQLS FOR NOW, TEST ABOVE SQLS
-- trevors'

UPDATE papartinvoiceline pil
SET adjustmentprice = pil.adjustmentprice + bob.oob_amount
FROM (
	SELECT partinvoicelineid,
		sum(debitamt) AS debits,
		sum(creditamt) AS credits,
		(sum(debitamt) - sum(creditamt)) AS OOB_Amount,
		pil.adjustmentprice
	FROM papartinvoiceline pil -- select the list of part invoice lines
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid -- join to compare commoninvoicenumber and management activity
	INNER JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid -- join to grab list of all management activity accounting entries to be made
	WHERE ba.invoicenumber = '119754' 
	    AND qtysold = 10000 -- where quantity sold is only 1
	GROUP BY partinvoicelineid -- allows totalling per part invoice line
	ORDER BY pil.adjustmentprice DESC
	LIMIT 1
	) bob
WHERE bob.partinvoicelineid = pil.partinvoicelineid

-- OR, if there is more than one part sold on all lines, you can try this one

UPDATE papartinvoiceline pil
SET adjustmentprice = adjustmentprice + bob.test
FROM (
	SELECT partinvoicelineid,
		sum(debitamt) AS debits,
		sum(creditamt) AS credits,
		(sum(debitamt) - sum(creditamt)) AS OOB_Amount,
		(Round(((sum(debitamt) - sum(creditamt)) / qtysold), 4) * 10000)::INTEGER AS test
	FROM papartinvoiceline pil
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	INNER JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	WHERE ba.invoicenumber = '318518'
	GROUP BY partinvoicelineid LIMIT 1
	) bob
WHERE bob.partinvoicelineid = pil.partinvoicelineid;
