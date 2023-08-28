-- EVO-20828 List of Updates that may or may not work
--
-- SQL Description: this is just a list of potential updates to use on 20828 related issues 
-- How to Use: Copy the SQL statement, and modify based on comments above the SQL
-- Jira Key/CR Number: EVO-20828 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-20828
-- SQL Statement:




-- trevor's

UPDATE papartinvoiceline pil
SET adjustmentprice = adjustmentprice + bob.oob_amount
FROM (
	SELECT partinvoicelineid,
		sum(debitamt) AS debits,
		sum(creditamt) AS credits,
		(sum(debitamt) - sum(creditamt)) AS OOB_Amount
	FROM papartinvoiceline pil
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	INNER JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	WHERE ba.invoicenumber = '119754'
	GROUP BY partinvoicelineid LIMIT 1
	) bob
WHERE bob.partinvoicelineid = pil.partinvoicelineid;


-- riley's

-- EVO-20828
-- Invoice xxxxx
UPDATE papartinvoiceline
SET adjustmentprice = adjustmentprice - data.dif
FROM (
	SELECT pit.soldnowsubtotal AS true,
		pi.invoicecollectamt AS false,
		pi.partinvoiceid AS piid,
		pil.partinvoicelineid as pilid,
		(pit.soldnowsubtotal - pi.invoicecollectamt) AS dif,
		pil.adjustmentprice as incorrectamount,
		(pil.adjustmentprice - (pit.soldnowsubtotal - pi.invoicecollectamt)) as correctamount
	FROM papartinvoice pi
	INNER JOIN papartinvoicetotals pit ON pi.partinvoiceid = pit.partinvoiceid
	Inner join papartinvoiceline pil on pi.partinvoiceid = pil.partinvoiceid
	WHERE pil.partinvoicelineid = xxxxxxx
	) data
WHERE partinvoicelineid = data.pilid;