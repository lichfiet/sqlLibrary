SELECT p.partnumber,
	po.purchaseordernumber,
	(((incomingqty) - (outgoingqty)) * .0001),
	po.purchaseordernumber,
	ps.packingslip,
	(ROUND(ph.replacementcost, 2) * ((incomingqty) - (outgoingqty))),
	ph.replacementcost
--ROUND((sum(ph.replacementcost * (incomingqty - outgoingqty) * .0001)) * .0001, 2),
--CASE WHEN (sum(incomingqty) - sum(outgoingqty)) * .0001 != 0 THEN ROUND(((sum(ph.replacementcost * (incomingqty - outgoingqty) * .0001)) / (sum(incomingqty) - sum(outgoingqty))), 2) ELSE 0 END
FROM paparthistory ph
INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = ph.receivingdocumentid
INNER JOIN papurchaseorder po ON po.purchaseorderid = ph.purchaseorderid
INNER JOIN papartshipment ps ON ps.partshipmentid = rd.partshipmentid
INNER JOIN papart p ON p.partid = ph.partid
WHERE initiatingaction = 8
	AND ps.packingslip = '6023259565'
--	AND p.partnumber = '76630036000'
-- AND ph.purchaseorderlineid = 
ORDER BY p.partnumber ASC
