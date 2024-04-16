-- making it beautiful
WITH debit_applied
AS (
	SELECT accountingid,
		storeid,
		acctdeptid,
		ardocdbid,
		SUM(ABS(appliedamt)) AS sum_appliedamt
	FROM arapplyitem
	WHERE accountingid = 1
		--AND storeid = 2
		AND acctdeptid = 501600759610082833
		AND ardocdbid <> ardoccrid
	GROUP BY accountingid,
		storeid,
		acctdeptid,
		ardocdbid
	),
credit_applied
AS (
	SELECT accountingid,
		storeid,
		acctdeptid,
		ardoccrid,
		SUM(ABS(appliedamt)) AS sum_appliedamt
	FROM arapplyitem
	WHERE accountingid = 1
		--AND storeid = 2
		AND acctdeptid = 501600759610082833
		AND ardocdbid <> ardoccrid
	GROUP BY accountingid,
		storeid,
		acctdeptid,
		ardoccrid
	)
SELECT accountingid,
	locationid,
	schedule,
	acctdept,
	glhistoryid,
	acctdesc,
	customernumber,
	customername,
	postingdate,
	DATE,
	journaldescription,
	schedxrefid,
	scheduleidentifier,
	documentnumber,
	description,
	amount,
	CASE rownumber
		WHEN 1
			THEN last_sum_amount
		ELSE 0
		END AS sum_amount,
	CASE rownumber
		WHEN 1
			THEN sum_appliedamt
		ELSE 0
		END AS sum_appliedamt
FROM (
	SELECT *,
	    /* */
		last_value(sum_amount) OVER (
			PARTITION BY h2.accountingid, h2.locationid, h2.acctdeptid, h2.schedacctid,h2.scheduleidentifier
			) AS last_sum_amount
	FROM (
		SELECT 
		    -- GL HIST AND ACCOUNT INFORMATION
		    h.accountingid,
			h.locationid,
			h.acctdeptid,
			h.schedacctid,
			h.postingdate,
			h.DATE,
			h.jtypeid,
			h.schedxrefid,
			h.scheduleidentifier,
			h.documentnumber,
			h.description,
			-- CUSTOMER INFORMATION
			COALESCE(cust.searchname, '')       AS customername,
			COALESCE(cust.customernumber, 0)    AS customernumber,
			COALESCE(j.journaldescription, '')  AS journaldescription,
			COALESCE(gl.schedule, 0)            AS schedule,
			COALESCE(gl.acctdept, '')           AS acctdept,
			COALESCE(gl.acctdesc, '')           AS acctdesc,
			SUM(CASE 
					WHEN h.isconverted = true
						THEN COALESCE(glsl.docamt, 0)
					ELSE h.amtdebit - h.amtcredit
					END) OVER (
				PARTITION BY h.accountingid,
				h.locationid,
				h.acctdeptid,
				h.schedacctid,
				h.scheduleidentifier ORDER BY h.accountingid,
					h.locationid,
					h.acctdeptid,
					h.schedacctid,
					h.DATE,
					h.scheduleidentifier
				) AS sum_amount,
			CASE 
				WHEN MAX(c.sum_appliedamt) OVER (
						PARTITION BY h.accountingid,
						h.locationid,
						h.acctdeptid,
						h.schedacctid,
						h.scheduleidentifier ORDER BY h.accountingid,
							h.locationid,
							h.acctdeptid,
							h.schedacctid,
							h.DATE,
							h.scheduleidentifier
						) IS NULL
					THEN COALESCE(MAX(d.sum_appliedamt) OVER (
								PARTITION BY h.accountingid,
								h.locationid,
								h.acctdeptid,
								h.schedacctid,
								h.scheduleidentifier ORDER BY h.accountingid,
									h.locationid,
									h.acctdeptid,
									h.schedacctid,
									h.DATE,
									h.scheduleidentifier
								), 0)
				ELSE (
						COALESCE(MAX(c.sum_appliedamt) OVER (
								PARTITION BY h.accountingid,
								h.locationid,
								h.acctdeptid,
								h.schedacctid,
								h.scheduleidentifier ORDER BY h.accountingid,
									h.locationid,
									h.acctdeptid,
									h.schedacctid,
									h.DATE,
									h.scheduleidentifier
								), 0) * - 1
						)
				END AS sum_appliedamt,
			(
				ROW_NUMBER() OVER (
					PARTITION BY h.accountingid, h.locationid, h.acctdeptid, h.schedacctid, h.scheduleidentifier 
					ORDER BY h.accountingid, h.locationid, h.acctdeptid, h.schedacctid, h.DATE, h.scheduleidentifier
					)
				) AS rownumber,
			h.glhistoryid
		FROM glhistory h
		LEFT JOIN glsltransaction glsl ON h.accountingid = glsl.accountingid
			AND h.locationid = glsl.storeid
			AND h.schedxrefid = glsl.sltrxid
		LEFT JOIN credit_applied c ON h.accountingid = c.accountingid
			AND h.locationid = c.storeid
			AND h.acctdeptid = c.acctdeptid
			AND h.scheduleidentifier = c.ardoccrid
		LEFT JOIN debit_applied d ON h.accountingid = d.accountingid
			AND h.locationid = d.storeid
			AND h.acctdeptid = d.acctdeptid
			AND h.scheduleidentifier = d.ardocdbid
		LEFT JOIN cocustomer cust ON h.accountingid = cust.accountingid
			AND h.schedacctid = COALESCE(cust.customerid, 0)::TEXT
		LEFT JOIN gljournaltype j ON h.accountingid = j.accountingid
			AND h.jtypeid = j.journaltypeid
		INNER JOIN glchartofaccounts gl ON h.accountingid = gl.accountingid
			AND h.acctdeptid = gl.acctdeptid
		WHERE h.accountingid = 1
			AND gl.acctdept = '22000'
			AND (
				h.isconverted = false
				OR (
					h.isconverted = true
					AND scheduleidentifier > 0
					)
				)
		) h2
	ORDER BY h2.accountingid,
		h2.locationid,
		h2.acctdeptid,
		h2.schedacctid,
		h2.DATE,
		h2.scheduleidentifier,
		h2.rownumber
	) h3
WHERE last_sum_amount <> sum_appliedamt
	AND customernumber = '9887';
