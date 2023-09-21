-- update preapproved
-- EVO-14212
DELETE
FROM glconsxref
WHERE glconsxrefid IN (
		SELECT glconsxrefid
		FROM glconsxref cxr
		LEFT JOIN glchartofaccounts consacct ON consacct.acctdeptid = cxr.consacctdeptid
		LEFT JOIN glchartofaccounts detacct ON detacct.acctdeptid = cxr.acctdeptid
		WHERE detacct.acctdeptid IS NULL
			OR consacct.acctdeptid IS NULL
		)
