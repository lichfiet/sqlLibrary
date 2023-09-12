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
		('-' || newd.deptcode) AS newdepartment,
		coa.accountingid
	FROM glchartofaccounts coa
	-- join to find new dept code
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	INNER JOIN gldepartment newd ON ('-' || newd.deptcode) = (RIGHT(coa.acctdept, 3))
		AND newd.accountingid = coa.accountingid
	WHERE coa.accountingid = 5
	ORDER BY ('-' || newd.deptcode),
		coa.acctdept
	) meow
WHERE meow.acctid = coa.acctdeptid;

-- reorganizes department accounts
UPDATE glchartofaccounts coa
SET sequencenumber = bob.epicsequencenumber
FROM (
	SELECT coa.acctdeptid as id,
	row_Number() OVER (
			PARTITION BY d.deptcode ORDER BY regexp_replace(coa.acctdept, '[^0-9]+', '', 'g')
			) + (d.deptcode::INT * 1000000) AS epicsequencenumber,
		CASE 
			WHEN textregexeq(coa.acctdept, '^[[:digit:]]+(\.[[:digit:]]+)?$') = true
				THEN 0
			ELSE 1
			END,
		d.deptcode,
		regexp_replace(coa.acctdept, '[^0-9]+', '', 'g'),
		textregexeq(coa.acctdept, '^[[:digit:]]+(\.[[:digit:]]+)?$') AS isnumeric,
		CASE 
			WHEN d.deptcode = ''
				THEN 0
			ELSE cast(d.deptcode AS INT)
			END AS test,
		*
	FROM glchartofaccounts coa
	INNER JOIN (
		SELECT acctdeptid,
			deptcode
		FROM glchartofaccounts
		INNER JOIN gldepartment ON deptid = departmentsid
		) row ON row.acctdeptid = coa.acctdeptid
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	WHERE d.deptcode != ''
	ORDER BY d.deptcode,
		row_Number() OVER (
			PARTITION BY d.deptcode ORDER BY regexp_replace(coa.acctdept, '[^0-9]+', '', 'g')
			)
	) bob
WHERE bob.id = coa.acctdeptid



