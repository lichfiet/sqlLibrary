SELECT CASE 
		-- whether it's income or cogs
		WHEN lsfr.sortorder % 2 = 0
			AND lsfr.sortorder >= 5014 -- revenue = 1 cogs = 0
			THEN 'Revenue Field'
		WHEN lsfr.sortorder >= 5014
			AND lsfr.sortorder % 2 != 0
			THEN 'Cost of Goods Field'
		END AS rev_or_cgs,
	lsfr.fieldkey,
	coa.acctdept,
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
FROM lsfreportfield lsfr
INNER JOIN lsfreportfieldaccount lsfra ON lsfra.fieldid = lsfr.fieldid
RIGHT JOIN glchartofaccounts coa ON coa.acctdeptid = lsfra.accountid
WHERE CASE 
		WHEN (
				-- non detail account mapped in P&L section
				coa.headerdetailtotalcons != 2
				AND lsfr.sortorder >= 5014
				)
			THEN 1
		WHEN (
				-- income or cost account in a cost or income field
				lsfr.sortorder >= 5014
				AND (
					(
						-- is income account but mapped to cogs
						sortorder % 2 = 0
						AND coa.accttype = 3
						)
					OR (
						-- is cogs account but mapped to income
						sortorder % 2 != 0
						AND coa.accttype = 6
						)
					)
				)
			THEN 2
		WHEN (
				coa.headerdetailtotalcons = 2
				AND lsfr.fieldid IS NULL
				AND coa.accttype IN (3, 4, 6)
				)
			THEN 3
		END = 3
	AND coa.accountingid = 11
