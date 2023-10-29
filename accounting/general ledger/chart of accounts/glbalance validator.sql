-- find balance discrepancies in glblance

WITH dates
AS (
	SELECT glhistoryid,
		SUBSTRING(DATE::VARCHAR, 6, 2) AS month,
		SUBSTRING(DATE::VARCHAR, 1, 4) AS year
	FROM glhistory
	WHERE acctdeptid = 676582633517673126
	),
yeartomonth
AS (
	SELECT (
			CASE 
				WHEN d.month = '01'
					THEN beginningbalance + month1
				WHEN d.month = '02'
					THEN beginningbalance + month1 + month2
				WHEN d.month = '03'
					THEN beginningbalance + month1 + month2 + month3
				WHEN d.month = '04'
					THEN beginningbalance + month1 + month2 + month3 + month4
				WHEN d.month = '05'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5
				WHEN d.month = '06'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6
				WHEN d.month = '07'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7
				WHEN d.month = '08'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8
				WHEN d.month = '09'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9
				WHEN d.month = '10'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10
				WHEN d.month = '11'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11
				WHEN d.month = '12'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11 + month12
				ELSE NULL
				END * .0001
			) AS ytmonth,
		d.year AS year,
		d.month AS month,
		h.acctdeptid AS acctdeptid,
		b.storeid
	FROM glhistory h
	INNER JOIN (
		SELECT glhistoryid,
			SUBSTRING(DATE::VARCHAR, 6, 2) AS month,
			SUBSTRING(DATE::VARCHAR, 1, 4) AS year
		FROM glhistory
		) d ON h.glhistoryid = d.glhistoryid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	INNER JOIN glbalance b ON b.acctdeptid = h.acctdeptid
		AND b.fiscalyear::VARCHAR = d.year
	WHERE h.acctdeptid = 676582633517673126
	GROUP BY d.year,
		d.month,
		b.storeid,
		(
			CASE 
				WHEN d.month = '01'
					THEN beginningbalance + month1
				WHEN d.month = '02'
					THEN beginningbalance + month1 + month2
				WHEN d.month = '03'
					THEN beginningbalance + month1 + month2 + month3
				WHEN d.month = '04'
					THEN beginningbalance + month1 + month2 + month3 + month4
				WHEN d.month = '05'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5
				WHEN d.month = '06'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6
				WHEN d.month = '07'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7
				WHEN d.month = '08'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8
				WHEN d.month = '09'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9
				WHEN d.month = '10'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10
				WHEN d.month = '11'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11
				WHEN d.month = '12'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11 + month12
				ELSE NULL
				END * .0001
			),
		h.acctdeptid
	),
prevyeartomonth
AS (
	SELECT (
			CASE 
				WHEN d.month = '01'
					THEN beginningbalance
				WHEN d.month = '02'
					THEN beginningbalance + month1
				WHEN d.month = '03'
					THEN beginningbalance + month1 + month2
				WHEN d.month = '04'
					THEN beginningbalance + month1 + month2 + month3
				WHEN d.month = '05'
					THEN beginningbalance + month1 + month2 + month3 + month4
				WHEN d.month = '06'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5
				WHEN d.month = '07'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6
				WHEN d.month = '08'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7
				WHEN d.month = '09'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8
				WHEN d.month = '10'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9
				WHEN d.month = '11'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10
				WHEN d.month = '12'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11
				ELSE NULL
				END * .0001
			) AS prevytmonth,
		d.year AS year,
		d.month AS month,
		h.acctdeptid AS acctdeptid,
		b.storeid
	FROM glhistory h
	INNER JOIN (
		SELECT glhistoryid,
			SUBSTRING(DATE::VARCHAR, 6, 2) AS month,
			SUBSTRING(DATE::VARCHAR, 1, 4) AS year
		FROM glhistory
		) d ON h.glhistoryid = d.glhistoryid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
	INNER JOIN glbalance b ON b.acctdeptid = h.acctdeptid
		AND b.fiscalyear::VARCHAR = d.year
	WHERE h.acctdeptid = 676582633517673126
	GROUP BY d.year,
		d.month,
		b.storeid,
		(
			CASE 
				WHEN d.month = '01'
					THEN beginningbalance
				WHEN d.month = '02'
					THEN beginningbalance + month1
				WHEN d.month = '03'
					THEN beginningbalance + month1 + month2
				WHEN d.month = '04'
					THEN beginningbalance + month1 + month2 + month3
				WHEN d.month = '05'
					THEN beginningbalance + month1 + month2 + month3 + month4
				WHEN d.month = '06'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5
				WHEN d.month = '07'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6
				WHEN d.month = '08'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7
				WHEN d.month = '09'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8
				WHEN d.month = '10'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9
				WHEN d.month = '11'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10
				WHEN d.month = '12'
					THEN beginningbalance + month1 + month2 + month3 + month4 + month5 + month6 + month7 + month8 + month9 + month10 + month11
				ELSE NULL
				END * .0001
			),
		h.acctdeptid
	)
SELECT CASE 
		WHEN (
				pytm.storeid != sm.childstoreid
				OR ytm.storeid != sm.childstoreid
				)
			THEN 'balance entry in wrong store'
		ELSE ''
		END AS entryincorrectstore,
	(sum(amtcredit) * .0001) - (sum(amtdebit) * .0001) AS sum,
	pytm.prevytmonth AS prevyeartomonthbalance,
	ytm.ytmonth AS endofmonthbalance,
	d.month,
	d.year,
	h.acctdeptid,
	sm.childstoreid,
	ytm.storeid,
	pytm.storeid
FROM glhistory h
INNER JOIN costoremap sm ON sm.parentstoreid = h.accountingid
INNER JOIN dates d ON h.glhistoryid = d.glhistoryid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = h.acctdeptid
INNER JOIN yeartomonth ytm ON ytm.acctdeptid = h.acctdeptid
	AND d.year = ytm.year
	AND d.month = ytm.month
INNER JOIN prevyeartomonth pytm ON pytm.acctdeptid = h.acctdeptid
	AND d.year = pytm.year
	AND d.month = pytm.month
WHERE h.acctdeptid = 676582633517673126
GROUP BY d.year,
	d.month,
	pytm.prevytmonth,
	ytm.ytmonth,
	h.acctdeptid,
	sm.childstoreid,
	pytm.storeid,
	ytm.storeid,
	CASE 
		WHEN (
				pytm.storeid != sm.childstoreid
				OR ytm.storeid != sm.childstoreid
				)
			THEN 'balance entry in wrong store'
		ELSE ''
		END
HAVING (ytm.ytmonth != (pytm.prevytmonth + (sum(amtcredit) * .0001) - (sum(amtdebit) * .0001)));

/* Updated SQL | After running this SQL, recalculate the chart of accounts and it will correct any issues. Recalculating will resolve issues with the GL Balance table as well where there may be duplicate entries. */

