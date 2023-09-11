-- sets accounts to new department and code and acctdept, based on if they had an acctcode including a deptcode
UPDATE glchartofaccounts coa
SET acctcode = meow.newacctcode,
	acctdept = meow.newacctdept,
	deptid = meow.newdepartmentid
FROM (
	SELECT CASE 
			WHEN RIGHT(coa.acctcode, 3) = ('-' || newd.deptcode)
				THEN LEFT(coa.acctcode, (LENGTH(coa.acctcode) - 3))
			ELSE acctcode
			END AS newacctcode,
		CASE 
			WHEN RIGHT(coa.acctcode, 3) = ('-' || newd.deptcode)
				THEN LEFT(coa.acctcode, (LENGTH(coa.acctcode) - 3)) || ('-' || newd.deptcode)
			ELSE acctcode || ('-' || newd.deptcode)
			END AS newacctdept,
		coa.acctdeptid AS acctid,
		coa.acctdept AS currdept,
		coa.acctcode AS currcode,
		newd.departmentsid AS newdepartmentid,
		coa.deptid AS currdepartmentid,
		'-' || d.deptcode AS currdeptcode,
		('-' || newd.deptcode) AS newdepartment
	FROM glchartofaccounts coa
	-- join to find new dept code
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	INNER JOIN gldepartment newd ON ('-' || newd.deptcode) = (RIGHT(coa.acctdept, 3))
		AND newd.accountingid = coa.accountingid
	--	AND newd.departmentsid != coa.deptid
	-- join to find new sequence number
	ORDER BY ('-' || newd.deptcode),
		coa.acctdept
	) meow
WHERE meow.acctid = coa.acctdeptid


SELECT row_Number() OVER (
		PARTITION BY deptid ORDER BY coa.acctdept
		),
	*
FROM glchartofaccounts coa
INNER JOIN (
	SELECT acctdeptid,
		deptcode
	FROM glchartofaccounts
	INNER JOIN gldepartment ON deptid = departmentsid
	) row ON row.acctdeptid = coa.acctdeptid
WHERE accountingid = 5

