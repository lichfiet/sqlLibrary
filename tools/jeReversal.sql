SELECT h.documentnumber,
	left(h.DATE::VARCHAR, 9) AS DATE,
	coa.acctdept AS accountnumber,
	ROUND(amtcredit * .0001, 2) AS credit,
	ROUND(amtdebit * .0001, 2) AS debit,
	description || ' - Reversal' AS description1,
	0 AS description2,
	'reverse entry' AS ref1,
	0 AS ref2,
	h.locationid
FROM glhistory h
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
WHERE journalentryid IN --(2336952, 2336953, 2336954, 2336955, 2336956, 2336957, 2336958, 2336959, 2336960, 2336961, 2336962, 2336963, 2336964, 2336965, 2336966, 2336967)
ORDER BY documentnumber

-- Alt select for MAE documents that haven't posted

SELECT ba.documentnumber,
	left(bai.dtstamp::VARCHAR, 9) AS dtstamp,
	coa.acctdept AS accountnumber,
	ROUND(debitamt * .0001, 2) AS debitamt,
	ROUND(creditamt * .0001, 2) AS creditamt,
	description || ' - Reversal' AS description1,
	0 AS description2,
	'reverse entry' AS ref1,
	0 AS ref2,
	ba.storeid
FROM mabusinessactionitem bai
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = bai.accountid
INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
WHERE ba.STATUS != 1
	AND ba.documentnumber = 'DOCUMENT NUMBER'

