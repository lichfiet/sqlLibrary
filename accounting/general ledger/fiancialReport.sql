SELECT 'Account ' || coa.acctdept || ' is mapped multiple times' AS error,
	coa.accountingid,
	coa.acctdesc,
	count(coa.acctdeptid),
	CASE 
		WHEN coa.accttype = 1
			THEN 'Asset'
		WHEN coa.accttype = 2
			THEN 'Liability'
		WHEN coa.accttype = 3
			THEN 'Revenue'
		WHEN coa.accttype = 4
			THEN 'Expense'
		WHEN coa.accttype = 5
			THEN 'Owners Equity'
		WHEN coa.accttype = 6
			THEN 'Cost of Goods'
		END AS account_mode
FROM lsfreportfield lsfr
INNER JOIN lsfreportfieldaccount lsfra ON lsfra.fieldid = lsfr.fieldid
RIGHT JOIN glchartofaccounts coa ON coa.acctdeptid = lsfra.accountid
WHERE accountingid = XXX
GROUP BY coa.acctdept,
	coa.accountingid,
	coa.acctdesc,
	coa.accttype
HAVING count(coa.acctdeptid) > 1;

WITH depts
AS (
	SELECT coa.accountingid,
		d.deptcode,
		row_number() OVER (
			PARTITION BY coa.accountingid ORDER BY avg(sequencenumber)
			) AS deptrank,
		coa.deptid
	FROM glchartofaccounts coa
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	GROUP BY coa.deptid,
		coa.accountingid,
		d.deptcode
	)
SELECT 'Account ' || coa.acctdept || ' is a(n) ' || CASE 
		WHEN coa.accttype = 1
			THEN 'Asset'
		WHEN coa.accttype = 2
			THEN 'Liability'
		WHEN coa.accttype = 3
			THEN 'Revenue'
		WHEN coa.accttype = 4
			THEN 'Expense'
		WHEN coa.accttype = 5
			THEN 'Owners Equity'
		WHEN coa.accttype = 6
			THEN 'Cost of Goods'
		END || ' account that is no mapped on the financial report',
	coa.accountingid,
	coa.acctdesc,
	CASE 
		WHEN coa.accttype = 1
			THEN 'Asset'
		WHEN coa.accttype = 2
			THEN 'Liability'
		WHEN coa.accttype = 3
			THEN 'Revenue'
		WHEN coa.accttype = 4
			THEN 'Expense'
		WHEN coa.accttype = 5
			THEN 'Owners Equity'
		WHEN coa.accttype = 6
			THEN 'Cost of Goods'
		END AS account_mode
FROM glchartofaccounts coa
LEFT JOIN lsfreportfieldaccount lsfra ON coa.acctdeptid = lsfra.accountid
LEFT JOIN lsfreportfield lsfr ON lsfra.fieldid = lsfr.fieldid
INNER JOIN depts ON depts.deptid = coa.deptid
INNER JOIN glbalanceytd b ON b.acctdeptid = coa.acctdeptid
-- AND b.fiscalyear = 2024
-- AND ytdmonth2 != 0
WHERE (
		(
			-- is consolidate expense account with no mapping
			coa.headerdetailtotalcons IN (4, 2)
			AND lsfr.fieldid IS NULL
			AND coa.accttype = 4
			AND depts.deptrank = 1
			)
		OR (
			-- is detail department rev or cogs with no mapping
			coa.headerdetailtotalcons IN (2)
			AND lsfr.fieldid IS NULL
			AND coa.accttype IN (3, 6)
			AND depts.deptrank != 1
			)
		)
	AND coa.accountingid = XXX;
