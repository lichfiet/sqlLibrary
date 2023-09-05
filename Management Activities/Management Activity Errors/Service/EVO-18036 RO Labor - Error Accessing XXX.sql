

-- DIAGNOSTIC // if a matching category is found, the second and third column will populate, and you can run Update 1,
-- if they show up blank, a matching category in the correct store does not exist and will need to be created.
-- If you do not want to make a category or would like to use on that already exists, please use Update 2.
--
-- To use: replace repair order number on line 22
--
SELECT DISTINCT repairorderlaborid AS ID,
	newcat.categorycode,
	newcat.categoryid,
	badcat.categorycode,
	badcat.categoryid,
	*
FROM serepairorderlabor rol
INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
INNER JOIN cocategory badcat ON badcat.categoryid = rol.categoryid
	AND badcat.storeid != rol.storeid
LEFT JOIN cocategory newcat ON newcat.categorycode = badcat.categorycode
	AND newcat.storeid = rol.storeid
INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
WHERE repairordernumber = 16941 -- replace me
	AND ba.STATUS = 2;

-- UPDATE // This will only work if the Diagnostic SQL's columns 2 and 3 were populated. If they were not,
-- you will need to use Update 2, or create the category in the correct store. If creating category, please
-- run the diagnostic again and make sure columns 2 and 3 are populated before trying the update.
UPDATE serepairorderlabor rol
SET categoryid = bob.newcategoryid
FROM (
	SELECT DISTINCT repairorderlaborid AS ID,
		newcat.categorycode,
		newcat.categoryid AS newcategoryid,
		badcat.categorycode,
		badcat.categoryid
	FROM serepairorderlabor rol
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
	INNER JOIN cocategory badcat ON badcat.categoryid = rol.categoryid
		AND badcat.storeid != rol.storeid
	INNER JOIN cocategory newcat ON newcat.categorycode = badcat.categorycode
		AND newcat.storeid = rol.storeid
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	WHERE repairordernumber = 16941
		AND ba.STATUS = 2
	) bob
WHERE bob.id = rol.repairorderlaborid
