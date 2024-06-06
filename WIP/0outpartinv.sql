INSERT INTO paparthistory
SELECT generate_luid(),
	bob.partid,
	now(),
	0, -- incomingqty
	bob.outgoingqty,
	bob.replacementcost,
	'Lightspeed 0 Inventory Adjustment', --- description
	1,
	bob.storeid,
	bob.userid,
	NULL, -- partinvoiceid
	NULL, -- partinvoiceline
	NULL, -- specialorderid
	NULL, -- solineid
	NULL, -- poid
	NULL, -- polineid
	NULL, -- ropartid
	NULL, -- mupartid
	NULL, -- dealunitpartid
	0, -- resultingonhandqty,
	0, -- resultingonhandavailable
	0, -- resultingonorderavailable
	0, -- resultingonorderqty
	0, -- resultingonspecialorder
	0, -- resultingweightedcost
	bob.lastsolddate,
	bob.lastreceiveddate,
	NULL, -- suppliereturnid
	NULL, -- suppliereturnlineid
	NULL, -- partshipmentid
	NULL, -- receivingdocid
	now(), -- eventdate
	bob.storeidluid,
	''
FROM (
	SELECT p.partid,
		(- 1 * ph.resultingonhandqty) AS outgoingqty,
		p.replacementcost,
		p.storeid,
		p.userid,
		ph.lastsolddate,
		ph.lastreceiveddate,
		ph.resultingonorderqty,
		ph.resultingonspecialorderqty,
		p.storeidluid,
		row_number() OVER (
			PARTITION BY p.partid ORDER BY eventdate DESC
			) AS rownum
	FROM papart p
	INNER JOIN paparthistory ph ON p.partid = ph.partid
	INNER JOIN pasupplier su ON su.supplierid = p.supplierid
	WHERE p.partnumber = '005402'
	) bob
WHERE resultingonorderqty = 0
	AND resultingonspecialorderqty = 0
	AND rownum = 1
