WITH searchdata
AS (
	SELECT /* */
		--
		-----------------------------------------------
		-- TRANSACTION DATE FILTER (Change the '1900-01-01' to a date YYYY-MM-DD)
		--
		/* Starting Date */ '1900-01-01 00:00:00'::TIMESTAMP AS from_date,
		/* Ending Date */ '1900-01-01 24:00:00'::TIMESTAMP AS through_date,
		-- 
		-- -----------------------------------------------
		-- ADDITIONAL FILTERS 
		-- 
		/* Method Of Payment */ 'method_of_payment' AS mop_desc,
		/* Deposited (OPTIONS: YES, NO, IGNORE) */ 'IGNORE' AS deposited,
		--
		--------------------------------------------------
		-- If Already deposited, use the below to filter by the deposit's dates
		--
		/* Deposited From Date */ '1900-01-01' AS dep_from_date,
		/* Deposited Through Date*/ '1900-01-01' AS dep_through_date
		--
		-----------------------------------------------
		--
	)
SELECT 'Doc #: (' || ba.documentnumber || ')' AS document_number,
	'MOP: ' || cip.description AS method_of_payment,
	'Amount: $' || ROUND(cip.amount * .0001, 2)::VARCHAR AS payment_amount,
	CASE 
		WHEN dba.businessactionid IS NULL
			THEN 'Not Deposited'
		ELSE 'Deposited'
		END AS deposited,
	'Deposit Dates: (' || coalesce(d.fromdate::VARCHAR, 'N/A') || ' -> ' || coalesce(d.thrudate::VARCHAR, 'N/A') || ')' AS deposit_dates,
	ba.documentdate::DATE
FROM mabusinessaction ba
INNER JOIN cocommoninvoice ci ON ci.invoicenumber::TEXT = ba.invoicenumber
INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
LEFT JOIN madepositbusinessaction dba ON dba.businessactionid = ba.businessactionid
LEFT JOIN madeposit d ON d.depositid = dba.depositid
INNER JOIN costore s ON s.storeid = ba.storeid
-- FILTERS
INNER JOIN searchdata sd ON (
		CASE 
			WHEN sd.from_date != '1900-01-01 00:00:00'
				AND sd.through_date != '1900-01-01 24:00:00'
				AND ba.documentdate::TIMESTAMP BETWEEN sd.from_date
					AND sd.through_date
				THEN 1
			WHEN sd.from_date = '1900-01-01 00:00:00'
				AND sd.through_date = '1900-01-01 24:00:00'
				THEN 1
			ELSE 0
			END
		) = 1
	AND (
		CASE 
			WHEN mop_desc != 'method_of_payment'
				AND cip.description = mop_desc
				THEN 1
			WHEN mop_desc = 'method_of_payment'
				THEN 1
			ELSE 0
			END
		) = 1
	AND (
		CASE 
			WHEN sd.deposited = 'YES'
				AND dba.businessactionid IS NOT NULL
				THEN 1
			WHEN sd.deposited = 'NO'
				AND dba.businessactionid IS NULL
				THEN 1
			WHEN sd.deposited = 'IGNORE'
				THEN 1
			ELSE 0
			END
		) = 1
	AND (
		CASE 
			WHEN sd.dep_from_date != '1900-01-01'
				AND sd.dep_through_date != '1900-01-01'
				AND d.fromdate = sd.dep_from_date::date
				AND d.thrudate = sd.dep_through_date::date
				THEN 1
			WHEN sd.dep_from_date = '1900-01-01'
				AND sd.dep_through_date = '1900-01-01'
				THEN 1
			ELSE 0
			END
		) = 1
WHERE cip.amount != 0
