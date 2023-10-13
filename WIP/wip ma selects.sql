WITH doctype
AS (
	SELECT businessactionid,
		CASE documenttype
			WHEN 1001
				THEN 'Parts Invoice'
			WHEN 1002
				THEN 'Parts Special Order Deposit'
			WHEN 1003
				THEN 'Miscellaneous Receipt'
			WHEN 1004
				THEN 'Paid Out'
			WHEN 1005
				THEN 'Inventory Update'
			WHEN 1006
				THEN 'Bar Code Download Update'
			WHEN 1007
				THEN 'Part Receiving Document'
			WHEN 1008
				THEN 'Part Return Document'
			WHEN 2001
				THEN 'Repair Order'
			WHEN 2002
				THEN 'Repair Order Deposit'
			WHEN 2003
				THEN 'Service Warranty Credit'
			WHEN 2004
				THEN 'Service Reverse RO'
			WHEN 2005
				THEN 'Sublet Closeout'
			WHEN 2006
				THEN 'Reverse Sublet Closeout'
			WHEN 3001
				THEN 'Sales Deal Finalize'
			WHEN 3002
				THEN 'Sales Deposit'
			WHEN 3003
				THEN 'Sales Major Unit'
			WHEN 3004
				THEN 'Sales Trade Purchase'
			WHEN 3005
				THEN 'Sales Repair Order Cancel Adjustment'
			WHEN 3006
				THEN 'Sales Deal Unfinalize'
			WHEN 3007
				THEN 'Sales Trade Unpurchase'
			WHEN 3008
				THEN 'Sales Major Unit Receiving'
			WHEN 3009
				THEN 'Major Unit Transfer Send'
			WHEN 3010
				THEN 'Major Unit Transfer Receive'
			WHEN 3011
				THEN 'Resolving Deal Adjustment'
			WHEN 4001
				THEN 'Rental Charge'
			WHEN 4002
				THEN 'Rental Payment'
			WHEN 4003
				THEN 'Rental Posting'
			WHEN 4004
				THEN 'Reservation Invoice'
			WHEN 4005
				THEN 'Reservation Receivables Conversion'
			WHEN 5001
				THEN 'Bank Deposit'
			WHEN 6001
				THEN 'AR Credit Card Payment'
			WHEN - 1
				THEN 'Unknown'
			ELSE 'Invalid Document Type' -- Add this line to handle unknown values
			END AS doctype
	FROM mabusinessaction ba
	WHERE ba.STATUS = 2
	),
oob
AS (
	SELECT documentnumber,
		sum(debitamt * .0001) AS debits,
		sum(creditamt * .0001) AS credits,
		(sum(debitamt * .0001) - sum(creditamt * .0001)) AS oobamt,
		CASE 
			WHEN (sum(debitamt * .0001) - sum(creditamt * .0001)) = 0
				THEN 'In Balance'
			ELSE 'Out Of Balance: Amount ' || (sum(debitamt * .0001) - sum(creditamt * .0001))::VARCHAR
			END AS oob,
		ba.businessactionid
	FROM mabusinessactionitem bai
	INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
errortxt
AS (
	SELECT row_number() OVER (
			PARTITION BY businessactionid ORDER BY businessactionerrorid ASC
			) AS num,
		CASE 
			WHEN length(errortext) < 40
				THEN errortext
			ELSE left(errortext, 37) || '...'
			END AS txt,
		*
	FROM mabusinessactionerror
	)
SELECT ba.documentnumber,
	doctype.doctype AS documenttype,
	LEFT((date_trunc('minute', documentdate))::VARCHAR, 16) AS DATE,
	errortxt.txt AS errormessage,
	s.storename,
	'-->' AS errorchecks,
	CASE 
		WHEN oob.oob IS NOT NULL
			THEN oob.oob
		ELSE 'N/A'
		END AS balancestate
FROM mabusinessaction ba
LEFT JOIN oob ON oob.businessactionid = ba.businessactionid
LEFT JOIN doctype ON doctype.businessactionid = ba.businessactionid
LEFT JOIN costore s ON s.storeid = ba.storeid
LEFT JOIN errortxt ON errortxt.businessactionid = ba.businessactionid
	AND num = 1
WHERE ba.STATUS = 2
ORDER BY s.storename ASC,
	documentdate DESC
