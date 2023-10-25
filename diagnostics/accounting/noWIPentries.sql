-- To find affected repair orders that are open
SELECT ro.repairordernumber, ro.dtstamp
FROM selaborsession ls
INNER JOIN serepairorderlabor rol ON ls.repairorderlaborid = rol.repairorderlaborid
INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
INNER JOIN setechnician t ON t.technicianid = ls.technicianid
	AND t.technicianrate != ls.technicianrate
WHERE STATE NOT IN (2, 3, 0) -- remove the 2 to see cashiered ROs
	AND ls.technicianrate = 0
	AND ro.storeid = 2
GROUP BY ro.repairordernumber,
	ro.dtstamp
ORDER BY ro.dtstamp DESC;

-- to find the labor sessions affected
SELECT ro.repairordernumber,
	ls.technicianrate AS laborsessionrate,
	t.technicianrate AS technicianrate,
	roj.title,
	*
FROM selaborsession ls
INNER JOIN serepairorderlabor rol ON ls.repairorderlaborid = rol.repairorderlaborid
INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
INNER JOIN setechnician t ON t.technicianid = ls.technicianid
	AND t.technicianrate != ls.technicianrate
WHERE STATE NOT IN (2, 3, 0) -- remove the 2 to see casiered ROs
	AND ls.technicianrate = 0
ORDER BY ro.dtstamp DESC;

