WITH maedata
AS (
	SELECT businessactionid,
		CASE documenttype
			WHEN 1001
				THEN 'Parts Invoice'
			WHEN 1002
				THEN 'Parts Special Order Deposit'
			WHEN 1003
				THEN 'Miscellaneous Receipt'
			WHEN 1004
				THEN 'Paid Out'
			WHEN 1005
				THEN 'Inventory Update'
			WHEN 1006
				THEN 'Bar Code Download Update'
			WHEN 1007
				THEN 'Part Receiving Document'
			WHEN 1008
				THEN 'Part Return Document'
			WHEN 2001
				THEN 'Repair Order'
			WHEN 2002
				THEN 'Repair Order Deposit'
			WHEN 2003
				THEN 'Service Warranty Credit'
			WHEN 2004
				THEN 'Service Reverse RO'
			WHEN 2005
				THEN 'Sublet Closeout'
			WHEN 2006
				THEN 'Reverse Sublet Closeout'
			WHEN 3001
				THEN 'Sales Deal Finalize'
			WHEN 3002
				THEN 'Sales Deposit'
			WHEN 3003
				THEN 'Sales Major Unit'
			WHEN 3004
				THEN 'Sales Trade Purchase'
			WHEN 3005
				THEN 'Sales Repair Order Cancel Adjustment'
			WHEN 3006
				THEN 'Sales Deal Unfinalize'
			WHEN 3007
				THEN 'Sales Trade Unpurchase'
			WHEN 3008
				THEN 'Sales Major Unit Receiving'
			WHEN 3009
				THEN 'Major Unit Transfer Send'
			WHEN 3010
				THEN 'Major Unit Transfer Receive'
			WHEN 3011
				THEN 'Resolving Deal Adjustment'
			WHEN 4001
				THEN 'Rental Charge'
			WHEN 4002
				THEN 'Rental Payment'
			WHEN 4003
				THEN 'Rental Posting'
			WHEN 4004
				THEN 'Reservation Invoice'
			WHEN 4005
				THEN 'Reservation Receivables Conversion'
			WHEN 5001
				THEN 'Bank Deposit'
			WHEN 6001
				THEN 'AR Credit Card Payment'
			WHEN - 1
				THEN 'Unknown'
			ELSE 'Invalid Document Type' -- Add this line to handle unknown values
			END AS doctype,
		CASE 
			WHEN STATUS = 2
				THEN 'Erroneous'
			WHEN STATUS = 4
				THEN 'Pending'
			ELSE 'Unknown'
			END AS errorstatus,
		LEFT((date_trunc('minute', documentdate))::VARCHAR, 16) AS docdate
	FROM mabusinessaction ba
	WHERE ba.STATUS = 2
	),
oob
AS (
	SELECT documentnumber,
		sum(debitamt * .0001) AS debits,
		sum(creditamt * .0001) AS credits,
		(sum(debitamt * .0001) - sum(creditamt * .0001)) AS oobamt,
		CASE 
			WHEN (sum(debitamt * .0001) - sum(creditamt * .0001)) = 0
				THEN 'In Balance'
			ELSE 'TLS-1362 Part Inv OOB'
			END AS oob,
		ba.businessactionid
	FROM mabusinessactionitem bai
	INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
missingmae
AS (
	SELECT businessactionid
	FROM mabusinessaction
	WHERE storeid = 0
		AND documentid = 0
		AND STATUS = 2
	),
errortxt
AS (
	SELECT row_number() OVER (
			PARTITION BY businessactionid ORDER BY businessactionerrorid ASC
			) AS num,
		CASE 
			WHEN length(errortext) < 40
				THEN errortext
			ELSE left(errortext, 37) || '...'
			END AS txt,
		*
	FROM mabusinessactionerror
	),
schedacctnotvalidar
AS (
	SELECT ma.businessactionid
	FROM mabusinessaction ma
	INNER JOIN mabusinessactionitem mai using (businessactionid)
	INNER JOIN cocommoninvoice ci ON ci.invoicenumber::TEXT = ma.invoicenumber::TEXT
	INNER JOIN cocommoninvoicepayment cip using (commoninvoiceid)
	INNER JOIN (
		SELECT CASE 
				WHEN depositoption = 0
					THEN bank_val
				WHEN depositoption IN (1, 2)
					THEN mop1.glacct
				END AS mop_gl,
			methodofpaymentid,
			mop1.storeid
		FROM comethodofpayment mop1
		INNER JOIN (
			SELECT value::BIGINT AS bank_val,
				storeid
			FROM copreference
			WHERE id = 'shop-DefaultBankAcct'
			) pref ON pref.storeid = mop1.storeid
		) mop ON mop.methodofpaymentid = cip.methodofpaymentid
		AND mop.storeid = ma.storeid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = mop.mop_gl
	WHERE STATUS = 2
		AND coa.schedule = 0
		AND cip.arcustomerid <> 0
		AND cip.dtstamp > '2022-03-15 00:00:00.000'
	GROUP BY ma.businessactionid
	),
erroraccropart
AS (
	SELECT ba.businessactionid
	FROM serepairorderpart rp
	INNER JOIN papart p ON p.partid = rp.partid
	INNER JOIN serepairorderjob rj ON rj.repairorderjobid = rp.repairorderjobid
	INNER JOIN serepairorderunit ru ON ru.repairorderunitid = rj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = ru.repairorderid
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	INNER JOIN cocategory c ON p.categoryid = c.categoryid
	WHERE ba.STATUS = 2
		AND rp.categoryid != p.categoryid
	GROUP BY ba.businessactionid
	),
erroraccrolabor
AS (
	SELECT businessactionid
	FROM serepairorderlabor rol
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
	INNER JOIN cocategory badcat ON badcat.categoryid = rol.categoryid
		AND badcat.storeid != rol.storeid
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	WHERE ba.STATUS = 2
	GROUP BY businessactionid
	),
erroraccpicat
AS (
	SELECT ba.businessactionid
	FROM mabusinessaction ba
	INNER JOIN papartinvoiceline pi ON pi.partinvoiceid = ba.documentid
	INNER JOIN cocategory c ON c.categoryid = pi.categoryid
		AND c.storeid != pi.storeid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
erroraccreceivepart
AS (
	SELECT businessactionid
	FROM (
		SELECT ba.businessactionid
		FROM papartadjustment pa
		INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = pa.receivingdocumentid
		LEFT JOIN mabusinessaction ba ON ba.documentid = rd.receivingdocumentid
		INNER JOIN papart p ON p.partid = pa.partid
		INNER JOIN cocategory c ON p.categoryid = c.categoryid
		WHERE ba.STATUS = 2
			AND ba.documentid IS NOT NULL
			AND c.isappmajorunit <> 1
			AND c.isfisales <> 1
		GROUP BY ba.businessactionid
		
		UNION
		
		SELECT ba.businessactionid
		FROM papurchaseorder pa
		INNER JOIN papartadjustment ph ON ph.referenceid = pa.purchaseorderid
		INNER JOIN pareceivingdocument rd ON ph.receivingdocumentid = rd.receivingdocumentid
		INNER JOIN papartshipment ps ON ps.partshipmentid = ph.partshipmentid
		INNER JOIN papart p ON p.partid = ph.partid
		INNER JOIN mabusinessaction ba ON rd.receivingdocumentid = ba.documentid
		WHERE ba.STATUS = 2
			AND (
				rd.storeid != p.storeid
				OR rd.storeidluid != p.storeidluid
				)
		GROUP BY ba.businessactionid
		) AS subquery
	GROUP BY businessactionid
	),
analysispending
AS (
	SELECT ba.businessactionid
	FROM papartadjustment pa
	INNER JOIN mabusinessaction ba ON ba.documentid = pa.receivingdocumentid
	INNER JOIN (
		SELECT max(partshipmentid) AS id,
			supplierid
		FROM papartshipment
		GROUP BY supplierid
		) cr ON cr.supplierid = pa.supplierid
	LEFT JOIN papartshipment ps ON ps.partshipmentid = pa.partshipmentid
	WHERE ps.partshipmentid IS NULL
		AND ba.STATUS = 4
		AND ba.documenttype = 1007
	),
invalidglnonpayro
AS (
	SELECT ma.businessactionid
	FROM serepairorderjob roj
	INNER JOIN serepairorderunit rou using (repairorderunitid)
	INNER JOIN serepairorder ro using (repairorderid)
	INNER JOIN cosaletype st ON st.saletypeid = roj.saletypeid
	INNER JOIN mabusinessaction ma ON ma.documentid = ro.repairorderid
	WHERE isnonpayjob = 1
		AND st.usagecode NOT IN (5, 7)
		AND ma.STATUS = 2
	GROUP BY ma.businessactionid
	),
invalidgldealandinvoice
AS (
	SELECT b.businessactionid
	FROM mabusinessaction b
	LEFT JOIN sadealfinalization df ON df.dealfinalizationid = b.documentid
	LEFT JOIN papartinvoice p ON p.partinvoiceid = b.documentid
	INNER JOIN cocommoninvoice c ON c.documentid = df.dealid
		OR c.documentid = p.partinvoiceid
	INNER JOIN cocommoninvoicepayment ci ON ci.commoninvoiceid = c.commoninvoiceid
	INNER JOIN comethodofpayment m ON m.methodofpaymentid = ci.methodofpaymentid
	LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = m.glacct
	WHERE b.STATUS = 2
		AND ci.description = ''
		AND ci.amount != 0
		AND coa.acctdeptid IS NULL
	GROUP BY b.businessactionid
	)
SELECT ba.documentnumber,
	maedata.doctype AS documenttype,
	maedata.errorstatus AS STATUS,
	maedata.docdate AS DATE,
	errortxt.txt AS errormessage,
	s.storename,
	'-->' AS errorchecks,
	CASE 
		WHEN oob.oob IS NOT NULL
			THEN oob.oob
		ELSE 'N/A'
		END AS balancestate,
	CASE 
		WHEN missingmae.businessactionid IS NOT NULL
			THEN 'EVO-20030'
		ELSE 'N/A'
		END AS missingmaefromfrontend,
	CASE 
		WHEN schedacctnotvalidar.businessactionid IS NOT NULL
			THEN 'EVO-38097'
		ELSE 'N/A'
		END AS schedacctnotvalidar,
	CASE 
		WHEN earop.businessactionid IS NOT NULL
			THEN 'EVO-26911'
		ELSE 'N/A'
		END AS erroraccropartcat,
	CASE 
		WHEN earol.businessactionid IS NOT NULL
			THEN 'EVO-18036'
		ELSE 'N/A'
		END AS erroraccrolaborcat,
	CASE 
		WHEN eapicat.businessactionid IS NOT NULL
			THEN 'EVO-13570'
		ELSE 'N/A'
		END AS erroraccpilpartcat,
	CASE 
		WHEN earpcat.businessactionid IS NOT NULL -- Error Accessing On Part Receiving Document
			THEN 'EVO-31748'
		ELSE 'N/A'
		END AS erroraccrecvpart,
	CASE 
		WHEN analysispending.businessactionid IS NOT NULL -- Analysis Pending On Part Receiving Document
			THEN 'EVO-34741'
		ELSE 'N/A'
		END AS analysispending,
	CASE 
		WHEN invalidglnonpayro.businessactionid IS NOT NULL -- Invalid GL For Non-Pay Job on Repair Order
			THEN 'EVO-34114'
		ELSE 'N/A'
		END AS invalidglnonpayro,
	CASE 
		WHEN invalidgldealandinvoice.businessactionid IS NOT NULL -- Invalid GL for MOP on Sales Deal or Part Invoice
			THEN 'EVO-35010'
		ELSE 'N/A'
		END AS invalidgldealandinvoice
FROM mabusinessaction ba
LEFT JOIN oob ON oob.businessactionid = ba.businessactionid
LEFT JOIN maedata ON maedata.businessactionid = ba.businessactionid
LEFT JOIN costore s ON s.storeid = ba.storeid
LEFT JOIN errortxt ON errortxt.businessactionid = ba.businessactionid
	AND num = 1
LEFT JOIN erroraccropart earop ON earop.businessactionid = ba.businessactionid -- EVO-26911 RO Part with Bad Categoryid
LEFT JOIN erroraccrolabor earol ON earol.businessactionid = ba.businessactionid -- EVO-18036 RO Labor with Bad Categoryid
LEFT JOIN erroraccpicat eapicat ON eapicat.businessactionid = ba.businessactionid -- EVO-13570 Part Invoice Line with Bad Categoryid
LEFT JOIN erroraccreceivepart earpcat ON earpcat.businessactionid = ba.businessactionid
LEFT JOIN missingmae ON missingmae.businessactionid = ba.businessactionid
LEFT JOIN analysispending ON analysispending.businessactionid = ba.businessactionid
LEFT JOIN invalidglnonpayro ON invalidglnonpayro.businessactionid = ba.businessactionid
LEFT JOIN invalidgldealandinvoice ON invalidgldealandinvoice.businessactionid = ba.businessactionid
LEFT JOIN schedacctnotvalidar ON schedacctnotvalidar.businessactionid = ba.businessactionid
WHERE ba.STATUS = 2
ORDER BY s.storename ASC,
	documentdate DESC
