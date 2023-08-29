-- jason rules
SELECT documentnumber,
	sum(debitamt * .0001) AS debits,
	sum(creditamt * .0001) AS credits,
	(sum(debitamt * .0001) - sum(creditamt * .0001)) AS oobamt,
	CASE 
		WHEN (sum(debitamt * .0001) - sum(creditamt * .0001)) = 0
			THEN 'In Balance'
		ELSE 'Out Of Balance'
		END AS oob
FROM mabusinessactionitem bai
INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
INNER JOIN cocommoninvoice ci ON CAST(ci.invoicenumber AS VARCHAR) = ba.invoicenumber
WHERE ci.invoicenumber = 4350995
GROUP BY ba.businessactionid;

SELECT cip.commoninvoicepaymentid AS id,
	*
FROM cocommoninvoicepayment cip
INNER JOIN cocommoninvoice ci ON ci.commoninvoiceid = cip.commoninvoiceid
INNER JOIN mabusinessaction ba ON CAST(ci.invoicenumber AS VARCHAR) = ba.invoicenumber
WHERE ci.invoicenumber = 4350995
	AND ba.STATUS = 2;
