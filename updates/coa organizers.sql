-- https://lightspeeddms.atlassian.net/browse/EVO-40147

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

-- reorganizes department accounts // reaplce the accountingid so it is store specific

UPDATE glchartofaccounts coa
SET sequencenumber = bob.epicsequencenumber
FROM (
	SELECT coa.acctdeptid AS id,
		row_Number() OVER (
			PARTITION BY d.deptcode ORDER BY regexp_replace(coa.acctdept, '[^0-9]+', '', 'g')
			) + (d.deptcode::INT * 1000000) AS epicsequencenumber,
		d.deptcode,
		textregexeq(coa.acctdept, '^[[:digit:]]+(\.[[:digit:]]+)?$') AS isnumeric,
		coa.acctdept,
		coa.acctcode
	FROM glchartofaccounts coa
	INNER JOIN gldepartment d ON d.departmentsid = coa.deptid
	WHERE d.deptcode NOT IN ('', '10')
		AND coa.accountingid = 5 -- REPLACE ME
	ORDER BY d.deptcode,
		row_Number() OVER (
			PARTITION BY d.deptcode ORDER BY regexp_replace(coa.acctdept, '[^0-9]+', '', 'g')
			)
	) bob
WHERE bob.id = coa.acctdeptid




