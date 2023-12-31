/* This CTE is used to defined common information for other CTEs and the base select query that 
references them. It includes the storeid to limit results in other CTEs, as well as the packing 
slip so both value can be changed inside only one section of the SQL*/
WITH data
AS (
	SELECT /* Change Me -> */ '123456' /* <- Change Me */ AS packingslip,
		/* Change Me -> */ 1 /* <- Change Me */ AS storeid
	),
ps
	/* This CTE selects information from papartshipment */
AS (
	SELECT ps.packingslip AS packingslipnum,
		ps.storeid AS psstoreid,
		*
	FROM papartshipment ps
	INNER JOIN data ON data.packingslip = ps.packingslip
		AND data.storeid = ps.storeid
	),
totalreceived
AS (
	SELECT purchaseorderlineid,
		ROUND(SUM(((incomingqty) - (outgoingqty)) * .0001), 2) AS totalreceived
	FROM paparthistory ph
	INNER JOIN data ON data.storeid = ph.storeid
	WHERE initiatingaction = 8
	GROUP BY purchaseorderlineid
	),
receivedonotherslips
AS (
	SELECT purchaseorderlineid,
		ROUND(SUM(((incomingqty) - (outgoingqty)) * .0001), 2) AS totalreceived
	FROM paparthistory ph
	INNER JOIN data ON data.storeid = ph.storeid
	LEFT JOIN ps ON ps.partshipmentid = ph.partshipmentid
		AND ps.psstoreid = ph.storeid
	WHERE initiatingaction = 8
		AND ps.partshipmentid IS NULL
	GROUP BY purchaseorderlineid
	)
SELECT p.partnumber,
	po.purchaseordernumber,
	tr.totalreceived AS receivedonallslips,
	ROUND(SUM(((incomingqty) - (outgoingqty)) * .0001), 2) AS receivedonthisslip,
	CASE 
		WHEN roos.totalreceived IS NULL
			THEN 0.00
		ELSE roos.totalreceived
		END AS receivedonotherslips,
	CASE 
		WHEN roos.totalreceived IS NOT NULL
			THEN tr.totalreceived - roos.totalreceived
		ELSE tr.totalreceived - ROUND(SUM(((incomingqty) - (outgoingqty)) * .0001), 2)
		END AS newreceivedqty,
	ps.packingslipnum
FROM paparthistory ph
INNER JOIN data ON data.storeid = ph.storeid
INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = ph.receivingdocumentid
INNER JOIN papurchaseorder po ON po.purchaseorderid = ph.purchaseorderid
INNER JOIN ps ON ps.partshipmentid = rd.partshipmentid
INNER JOIN papart p ON p.partid = ph.partid
INNER JOIN totalreceived tr ON tr.purchaseorderlineid = ph.purchaseorderlineid
LEFT JOIN receivedonotherslips roos ON roos.purchaseorderlineid = tr.purchaseorderlineid
WHERE initiatingaction = 8
GROUP BY p.partnumber,
	po.purchaseordernumber,
	ph.purchaseorderlineid,
	ps.packingslipnum,
	tr.totalreceived,
	roos.totalreceived
ORDER BY /* Order by whether all of the parts have been unreceived or not, and then by part number*/ (
		CASE 
			WHEN SUM(((incomingqty) - (outgoingqty)) * .0001) = 0
				THEN 1
			ELSE 0
			END
		) ASC,
	p.partnumber ASC
