-- EVO-34321 Delete for duplicate taxes
--
-- SQL Description:deletes dupe tax lines
-- How to Use: replace x's with the repair order number
-- Jira Key/CR Number: EVO-34321 | https://lightspeeddms.atlassian.net/browse/EVO-34321
-- SQL Statement:


--Written by John Scott
--The script still requires some testing to make sure its not a problem for other scenario's. Please contact John Scott if you encounter this issue. 
--It is also imperative that the script be ran in the proper order according to how it's laid out. Please do not edit this.
DELETE
FROM serepairordertaxentity fix USING (
		SELECT DISTINCT rote.repairordertaxitemid,
			rote.repairordertaxentityid,
			dup.*
		FROM serepairordertaxentity rote
		INNER JOIN serepairordertaxitem roti ON roti.repairordertaxitemid = rote.repairordertaxitemid
		INNER JOIN serepairorder ro ON ro.repairorderid = roti.repairorderid
		INNER JOIN (
			SELECT repairordertaxitemid AS myid,
				ROW_NUMBER() OVER (
					PARTITION BY taxcategoryid,
					description,
					groupid,
					taxtype,
					taxamount ORDER BY repairordertaxitemid ASC
					) AS Row
			FROM serepairordertaxitem
			) dup ON dup.myid = roti.repairordertaxitemid
		WHERE ro.repairordernumber = 'xxxxxxxx'
			AND ro.storeid = x
			AND rote.storeid = ro.storeid
			AND dup.row > 1
		) data
WHERE fix.repairordertaxentityid = data.repairordertaxentityid;

DELETE
FROM serepairordertaxitem roti USING (
		SELECT DISTINCT roti.repairordertaxitemid,
			roti.repairorderid,
			ro.storeid,
			roti.storeid,
			roti.dtstamp,
			dup.*
		FROM serepairordertaxitem roti
		INNER JOIN serepairorder ro ON ro.repairorderid = roti.repairorderid
		INNER JOIN (
			SELECT repairordertaxitemid AS myid,
				ROW_NUMBER() OVER (
					PARTITION BY taxcategoryid,
					description,
					groupid,
					taxtype,
					taxamount ORDER BY repairordertaxitemid ASC
					) AS Row
			FROM serepairordertaxitem
			) dup ON dup.myid = roti.repairordertaxitemid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ro.storeid = x
			AND roti.storeid = ro.storeid
			AND dup.row > 1
		ORDER BY roti.repairordertaxitemid ASC
		) data
WHERE roti.repairordertaxitemid = data.repairordertaxitemid;

DELETE
FROM mabusinessactionitem
WHERE businessactionitemid IN (
		SELECT bai.businessactionitemid
		FROM mabusinessactionitem bai
		INNER JOIN mabusinessaction ba USING (businessactionid)
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND bai.storeid = ba.storeid
		);

DELETE
FROM mabusinessactionerror
WHERE businessactionerrorid IN (
		SELECT bae.businessactionerrorid
		FROM mabusinessactionerror bae
		INNER JOIN mabusinessaction ba USING (businessactionid)
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND bae.storeid = ro.storeid
		);

DELETE
FROM mabusinessactiongroup
WHERE businessactiongroupid IN (
		SELECT bag.businessactiongroupid
		FROM mabusinessactiongroup bag
		INNER JOIN mabusinessaction ba USING (businessactionid)
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND bag.storeid = ba.storeid
		);

DELETE
FROM mabusinessactiontaxentityitem
WHERE businessactiontaxentityitemid IN (
		SELECT batei.businessactiontaxentityitemid
		FROM mabusinessactiontaxentityitem batei
		INNER JOIN mabusinessactiontaxitem bati USING (businessactiontaxitemid)
		INNER JOIN mabusinessaction ba ON ba.businessactionid = bati.businessactionid
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND batei.storeid = ba.storeid
		);

DELETE
FROM mabusinessactiontaxitem
WHERE businessactiontaxitemid IN (
		SELECT bati.businessactiontaxitemid
		FROM mabusinessactiontaxitem bati
		INNER JOIN mabusinessaction ba USING (businessactionid)
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND bati.storeid = ba.storeid
		);

DELETE
FROM madepositbusinessaction
WHERE depositbusinessactionid IN (
		SELECT dba.depositbusinessactionid
		FROM madepositbusinessaction dba
		INNER JOIN mabusinessaction ba USING (businessactionid)
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND dba.storeid = ba.storeid
		);

DELETE
FROM cocommoninvoicepayment
WHERE commoninvoicepaymentid IN (
		SELECT cip.commoninvoicepaymentid
		FROM mabusinessaction ba
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		INNER JOIN cocommoninvoice ci ON ci.documentid = ba.documentid
		INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND cip.storeid = ba.storeid
			AND ci.invoicenumber::TEXT <> ba.invoicenumber
		);

DELETE
FROM cocommoninvoice
WHERE commoninvoiceid IN (
		SELECT DISTINCT ci.commoninvoiceid
		FROM mabusinessaction ba
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		INNER JOIN cocommoninvoice ci ON ci.documentid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
			AND ci.storeid = ba.storeid
			AND ci.invoicenumber::TEXT <> ba.invoicenumber --This line may not always be consistant
		);

DELETE
FROM mabusinessaction
WHERE businessactionid IN (
		SELECT ba.businessactionid
		FROM mabusinessaction ba
		INNER JOIN serepairorder ro ON ro.repairorderid = ba.documentid
		WHERE ro.repairordernumber = 'xxxxxxx'
			AND ba.STATUS = 2
			AND ba.storeid = x
		);
