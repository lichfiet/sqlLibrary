-- EVO-14901 List of Updates that may or may not work
--
-- SQL Description: updates categoryid to correct issue on CR 
-- How to Use: replace values where it makes sense or is require, comments above sql should explain all
-- Jira Key/CR Number: EVO-20828 | https://lightspeeddms.atlassian.net/browse/EVO-14901
-- SQL Statement:

Update serepairorderpart rop
set categoryid = data.pcat
FROM
(Select rop.repairorderpartid, p.categoryid pcat, rop.categoryid from serepairorderpart rop
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rop.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
	INNER JOIN papart p ON p.partid = rop.partid
where ro.repairordernumber = 19195
and rop.partnumber = '201284'
and p.categoryid <> rop.categoryid)data
Where rop.repairorderpartid = data.repairorderpartid;

/* UPDATE AND DIAGNOSTIC FOR PART INVOICES
after running the diagnostic, the column updatestatus will tell you if you need to change the parts category. If it indicates a change is needed, 
if not corrected the update won't correct that part. if (Manual Update Required, See SQL Comments) is returned, you will need to manually update 
the part invoice line, using the sql after the update, labeled "manual part update" */

SELECT pi.partinvoicenumber,
	pil.partnumber,
	c.categorycode AS currcat,
	cpart.categorycode AS newcat,
	CASE 
		WHEN coa2.schedule = 0
			AND ismiscellaneousline = 0
			THEN 'Ready to Update'
		WHEN coa2.schedule != 0
			AND ismiscellaneousline = 0
			THEN 'Change Part Category'
		ELSE 'Manual Update Required, See SQL Comments'
		END AS updatestatus,
	pil.partinvoicelineid AS id
FROM papartinvoiceline pil
INNER JOIN papartinvoice pi ON pi.partinvoiceid = pil.partinvoiceid
INNER JOIN cocategory c ON c.categoryid = pil.categoryid
INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
LEFT JOIN papart p ON p.partid = pil.partid
INNER JOIN cocategory cpart ON cpart.categoryid = p.categoryid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
INNER JOIN glchartofaccounts coa2 ON cpart.glinventory = coa2.acctdeptid
WHERE coa.schedule != 0
	AND ba.STATUS = 2;

UPDATE papartinvoiceline pil
SET categoryid = bob.newcat,
	categorycode = bob.newcatcode
FROM (
	SELECT cpart.categoryid AS newcat,
		cpart.categorycode AS newcatcode,
		pil.partinvoicelineid AS id
	FROM papartinvoiceline pil
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = pil.partinvoiceid
	INNER JOIN cocategory c ON c.categoryid = pil.categoryid
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	LEFT JOIN papart p ON p.partid = pil.partid
	INNER JOIN cocategory cpart ON cpart.categoryid = p.categoryid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	INNER JOIN glchartofaccounts coa2 ON cpart.glinventory = coa2.acctdeptid
	WHERE coa.schedule != 0
		AND ba.STATUS = 2
		AND coa2.schedule = 0
	) bob
WHERE bob.id = pil.partinvoicelineid;

-- manual part update // replace the partinvoicelineid with the ID from the diagnostic, as well as the categorycode with a desired category code (case and space sensitive)

UPDATE papartinvoiceline pil
SET categoryid = bob.newcat,
	categorycode = bob.newcatcode
FROM (
	SELECT pil.partinvoicelineid AS id,
		newcat.categoryid,
		newcat.categorycode
	FROM papartinvoiceline pil
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = pil.partinvoiceid
	INNER JOIN cocategory c ON c.categoryid = pil.categoryid
	INNER JOIN glchartofaccounts coa ON c.glinventory = coa.acctdeptid
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	INNER JOIN cocategory newcat ON newcat.storeid = pil.storeid
	INNER JOIN glchartofaccounts coa2 ON newcat.glinventory = coa2.acctdeptid
	WHERE coa.schedule != 0
		AND ba.STATUS = 2
		AND coa2.schedule = 0
		AND newcat.categorycode = 'insert-desired-sales-category-code-here'
		AND pil.partinvoicelineid = 123456789 -- insert-part-invoice-line-id-here
		AND pil.ismiscellaneousline = 1
	) bob
WHERE bob.id = pil.partinvoicelineid;