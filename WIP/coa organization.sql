UPDATE glchartofaccounts coa
SET departmentid = meow.newdepartmentid,
	acctdept = meow.newdept
FROM (
	SELECT coa.acctdeptid AS glid,
		coa.acctdept,
		('-' || newd.deptcode) AS newdepartment,
		newd.departmentsid AS newdepartmentid,
		(RIGHT(coa.acctdept, 3)) AS currdepartment,
		LEFT(coa.acctdept, (LENGTH(acctdept) - 3)) AS newdept
	FROM glchartofaccounts coa
	INNER JOIN gldepartment newd ON ('-' || newd.deptcode) = (RIGHT(coa.acctdept, 3))
		AND newd.accountingid = coa.accountingid
	) meow
WHERE meow.glid = coa.acctdeptid;

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

