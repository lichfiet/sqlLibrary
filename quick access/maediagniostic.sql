WITH maedata
AS (
	SELECT ba.businessactionid,
		documentnumber,
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
		to_char(documentdate, 'YYYY / MM / DD') AS docdate,
		sum(bai.debitamt - creditamt * .0001) AS oobamt,
		CASE 
			WHEN sum(debitamt - creditamt) = 0
				THEN 'In Balance'
			ELSE 'Out of Balance!'
			END AS oob,
		left(string_agg(errortext, ''), 70) || '...' AS txt
	FROM mabusinessaction ba
	LEFT JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	LEFT JOIN mabusinessactionerror bae ON bae.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid,
		documentnumber,
		STATUS,
		documenttype
	),
missingmae
AS (
	SELECT businessactionid
	FROM mabusinessaction
	WHERE storeid = 0
		AND documentid = 0
		AND STATUS = 2
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
miscinvnonarmop
AS (
	SELECT ma.businessactionid
	FROM mabusinessaction ma
	INNER JOIN mabusinessactionitem mai using (businessactionid)
	INNER JOIN cocommoninvoice ci ON ci.invoicenumber::TEXT = ma.invoicenumber::TEXT
	INNER JOIN cocommoninvoicepayment cip using (commoninvoiceid)
	INNER JOIN comiscreceipttype mrt ON mrt.glacct = mai.accountid
	INNER JOIN pamiscinvoice mi ON mi.miscrectype = mrt.miscreceipttypeid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = mai.accountid
	WHERE STATUS = 2
		AND coa.schedule = 0
		AND mi.arcustomerid > 0
	GROUP BY ma.businessactionid
	),
dealarglaccount
AS (
	SELECT DUMP.errorid AS businessactionid
	FROM mabusinessactionitem bi
	INNER JOIN costoremap cm ON cm.childstoreid = bi.storeid
	LEFT JOIN cocustomer cc ON cc.customerid = bi.arid
	LEFT JOIN apvendor v ON v.vendorid = bi.apid
	INNER JOIN (
		SELECT accountingid AS prefAcctID,
			p.value AS APdefault,
			p2.value AS ARdefault
		FROM acpreference p
		INNER JOIN acpreference p2 USING (accountingid)
		WHERE p.id = 'acct-APPreferencesAPGLAcctDeptID'
			AND p2.id = 'acct-ARPreferencesReceivablesGLAcctDeptID'
		) pref ON pref.prefacctid = cm.parentstoreid
	INNER JOIN (
		SELECT ba1.businessactionid,
			ba1.invoicenumber,
			row_Number() OVER (
				PARTITION BY ba.documentnumber ORDER BY ba1.invoicenumber DESC
				) AS num,
			ba.businessactionid AS errorid
		FROM mabusinessaction ba
		INNER JOIN mabusinessaction ba1 USING (documentnumber)
		WHERE ba.STATUS = 2
			AND ba.documenttype = 3006
			AND ba1.documenttype = 3001
			AND ba1.invoicenumber < ba.invoicenumber
			AND ba.storeid = ba1.storeid
		) DUMP ON bi.businessactionid = DUMP.businessactionid
	WHERE (
			bi.apid != 0
			OR bi.arid != 0
			)
		AND DUMP.num = 1
		AND bi.accountid != CASE 
			WHEN overrideapacct = 1
				THEN apglacctdeptid
			WHEN overrideapacct <> 1
				THEN CAST(pref.APdefault AS BIGINT)
			WHEN arreceivablegloverride = 1
				THEN cc.arreceivableglacctdeptid
			WHEN arreceivablegloverride <> 1
				THEN CAST(pref.ARdefault AS BIGINT)
			END
	GROUP BY DUMP.errorid
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
		AND c.storeid != rp.storeid
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
	
	UNION
	
	SELECT ba.businessactionid -- this one probably needs a different CR but it has to do with the warranty company having a diff storeid for freight
	FROM serepairorder ro
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	INNER JOIN serepairorderunit rou ON rou.repairorderid = ro.repairorderid
	INNER JOIN serepairorderjob roj ON roj.repairorderunitid = rou.repairorderunitid
	INNER JOIN sewarrantyclaim wc ON wc.repairorderjobid = roj.repairorderjobid
	INNER JOIN cowarrantycompany warrcom ON warrcom.warrantycompanyid = wc.warrantycompanyid
	INNER JOIN cocategory currcat ON currcat.categoryid = warrcom.freightcategoryid
		AND currcat.storeid != warrcom.storeid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
erroraccmiscsaletype
AS (
	SELECT ba.businessactionid
	FROM serepairorder ro
	INNER JOIN cosaletype st ON st.saletypeid = ro.miscitemsaletypeid
		AND ro.storeid != st.storeid
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	WHERE ba.STATUS = 2
	GROUP BY ba.businessactionid
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
		INNER JOIN cocategory c ON pa.categoryid = c.categoryid
		WHERE ba.STATUS = 2
			AND ba.documentid IS NOT NULL
			AND c.storeid != pa.storeid
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
partinvoicescheduledmu
AS (
	SELECT ba.businessactionid
	FROM papartinvoiceline pil
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = pil.partinvoiceid
	INNER JOIN cocategory c ON c.categoryid = pil.categoryid
	INNER JOIN mabusinessaction ba ON ba.documentid = pil.partinvoiceid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	WHERE coa.schedule != 0
		AND ba.STATUS = 2
	GROUP BY ba.businessactionid
	
	UNION
	
	SELECT ba.businessactionid
	FROM papartadjustment pa
	INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = pa.receivingdocumentid
	INNER JOIN cocategory c ON c.categoryid = pa.categoryid
	INNER JOIN mabusinessaction ba ON ba.documentid = rd.receivingdocumentid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	WHERE coa.schedule != 0
		AND ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
analysispending -- verified to work at least once 
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
		AND p.invoicetype NOT IN (2, 3)
	INNER JOIN cocommoninvoice c ON c.documentid = df.dealid
		OR c.documentid = p.partinvoiceid
		OR c.commoninvoiceid = b.documentid
	INNER JOIN cocommoninvoicepayment ci ON ci.commoninvoiceid = c.commoninvoiceid
	INNER JOIN comethodofpayment mop ON mop.methodofpaymentid = ci.methodofpaymentid
	WHERE b.STATUS = 2
		AND ci.description = ''
		AND mop.description = ''
	GROUP BY b.businessactionid
	),
invalidglclaimsubmission
AS (
	SELECT ba.businessactionid AS businessactionid
	FROM mabusinessaction ba
	INNER JOIN sewarrantysubmissioncredit wsc ON wsc.warrantysubmissioncreditid = ba.documentid
	INNER JOIN sewarrantyclaimcredit using (warrantysubmissioncreditid)
	INNER JOIN sewarrantyclaim using (warrantyclaimid)
	INNER JOIN serepairorderjob roj using (repairorderjobid)
	INNER JOIN cosaletype st ON st.saletypeid = roj.saletypeid
	WHERE ba.STATUS = 2
		AND st.usagecode = 5
		AND ba.documenttype = 2003
		AND roj.warrantycompanyid <> wsc.warrantycompanyid
	GROUP BY ba.businessactionid
	),
taxidrental
AS (
	SELECT ba.businessactionid
	FROM rerentalpostingtaxdetail rptd
	INNER JOIN rerentalpostingtax rpt ON rpt.rentalpostingtaxid = rptd.rentalpostingtaxid
	INNER JOIN rerentalpostingitem rpi ON rpi.rentalpostingid = rpt.rentalpostingid
	INNER JOIN rerentalposting rp ON rp.rentalpostingid = rpi.rentalpostingid
	INNER JOIN mabusinessaction ba ON ba.documentnumber = rp.documentnumber
	INNER JOIN cotaxcategory tc ON tc.taxcategorydescription = rpt.description
		AND tc.storeid = rpt.storeid
	INNER JOIN cotax t ON t.taxcategoryid = tc.taxcategoryid
	LEFT JOIN cotax t2 ON t2.taxid = rptd.taxentityid
	WHERE ba.STATUS = 2
		AND t2.taxid IS NULL
	GROUP BY ba.businessactionid
	),
taxiddeal1
AS (
	SELECT ba.businessactionid
	FROM sadealunittax dut
	LEFT JOIN cotax t ON t.taxid = dut.taxentityid
	INNER JOIN cotaxcategory tc ON tc.taxcategorydescription = dut.taxcategorydescription
	INNER JOIN cotax t2 ON t2.taxcategoryid = tc.taxcategoryid
	INNER JOIN sadealunit du ON du.dealunitid = dut.dealunitid
	INNER JOIN sadeal d ON d.dealid = du.dealid
	INNER JOIN sadealfinalization f ON f.dealid = d.dealid
	INNER JOIN mabusinessaction ba ON ba.documentid = f.dealfinalizationid
	WHERE t.taxid IS NULL
		AND tc.storeid = dut.storeid
		AND ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
taxiddeal2 -- verified it works on two deals
AS (
	SELECT ba.businessactionid
	FROM sadeal d
	INNER JOIN sadealunit du ON du.dealid = d.dealid
	INNER JOIN sadealunittax dut ON dut.dealunitid = du.dealunitid
	INNER JOIN cotax t ON t.taxid = dut.taxentityid
	INNER JOIN cotax t1 ON t1.description ilike dut.taxdescription
		AND t1.storeid = dut.storeid
	INNER JOIN cotaxcategory tc ON tc.taxcategoryid = t1.taxcategoryid
	INNER JOIN sadealfinalization df ON df.dealid = d.dealid
	INNER JOIN mabusinessaction ba ON ba.documentid = df.dealfinalizationid
	WHERE ba.STATUS = 2
		AND t.storeid <> d.storeid
		AND d.finalizedate > '2018-10-01'
	GROUP BY ba.businessactionid
	),
taxidpartinvoice1
AS (
	SELECT ba.businessactionid
	FROM mabusinessaction ba
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = ba.documentid
	INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = pi.partinvoiceid
	INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
	LEFT JOIN cotax t ON t.taxid = pite.taxentityid
	LEFT JOIN cotax t1 ON t1.taxcategoryid = piti.taxcategoryid
	INNER JOIN cotaxcategory ct ON ct.taxcategoryid = piti.taxcategoryid
	WHERE ba.STATUS = 2
		AND t1.taxid <> t.taxid
		AND t1.description = t.description
		AND t1.taxid <> pite.taxentityid
		AND ct.taxcategoryid = t1.taxcategoryid
		OR (
			ba.STATUS = 2
			AND pite.taxentityid IS NULL
			)
	GROUP BY partinvoicetaxentityid,
		ba.businessactionid
	),
longvaltax -- https://lightspeeddms.atlassian.net/browse/EVO-37225
AS (
	SELECT ba.businessactionid
	FROM sadealadjustmenttax dat
	INNER JOIN sadealadjustment da ON da.dealadjustmentid = dat.dealadjustmentid
	INNER JOIN mabusinessaction ba ON ba.documentid = da.dealadjustmentid
	INNER JOIN (
		SELECT ba.businessactionid,
			STRING_AGG(errortext, ', ') AS TEXT
		FROM mabusinessactionerror bae
		INNER JOIN mabusinessaction ba ON ba.businessactionid = bae.businessactionid
		GROUP BY ba.businessactionid
		) errortext ON errortext.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
		AND errortext.TEXT ilike '%Tax Entity not rounded%'
		AND ROUND(taxamt, - 2) != taxamt
	GROUP BY ba.businessactionid
	
	UNION
	
	SELECT ba.businessactionid
	FROM rerentalpostingtaxdetail rptd
	INNER JOIN rerentalpostingtax rpt ON rpt.rentalpostingtaxid = rptd.rentalpostingtaxid
	INNER JOIN rerentalposting rp ON rp.rentalpostingid = rpt.rentalpostingid
	INNER JOIN mabusinessaction ba ON ba.documentid = rp.rentalpostingid
	INNER JOIN (
		SELECT ba.businessactionid,
			STRING_AGG(errortext, ', ') AS TEXT
		FROM mabusinessactionerror bae
		INNER JOIN mabusinessaction ba ON ba.businessactionid = bae.businessactionid
		GROUP BY ba.businessactionid
		) errortext ON errortext.businessactionid = ba.businessactionid
	WHERE ROUND(rptd.taxamount, - 2) != rptd.taxamount
		AND ba.STATUS = 2
		AND errortext.TEXT ilike '%Tax Entity not rounded%'
	GROUP BY ba.businessactionid
	),
dealunitid1 -- https://lightspeeddms.atlassian.net/browse/EVO-21635
AS (
	SELECT ba.businessactionid
	FROM samajorunit mu
	LEFT JOIN sadealunit x ON x.majorunitid = mu.majorunitid
	LEFT JOIN sadealunit x1 ON x1.dealunitid = mu.dealunitid
	INNER JOIN sadeal d ON d.dealid = x.dealid
	INNER JOIN sadealfinalization df ON df.dealid = d.dealid
	INNER JOIN mabusinessaction ba ON ba.businessactionid = df.dealfinalizationid
	WHERE mu.STATE = 2
		AND (
			x.dealunitid != 0
			OR x.dealunitid != NULL
			)
		AND d.STATE = 5
		AND x1.dealunitid IS NULL
		AND ba.STATUS = 2
	GROUP BY ba.businessactionid
	),
tradedealid
AS (
	SELECT businessactionid
	FROM mabusinessaction ba
	LEFT JOIN sadealtrade dt ON dt.dealtradeid = ba.documentid
	WHERE ba.STATUS = 2
		AND documenttype = 3007
		AND dt.dealtradeid IS NULL
	),
oobdupepartinvoice
AS (
	SELECT ba.businessactionid
	FROM paparthistory h
	INNER JOIN papartinvoice i ON h.partinvoiceid = i.partinvoiceid
	INNER JOIN papartinvoiceline il ON h.partinvoicelineid = il.partinvoicelineid
	LEFT JOIN paspecialorder so ON so.partinvoiceid = h.partinvoiceid
	INNER JOIN mabusinessaction ba ON ba.documentid = h.partinvoiceid
	WHERE il.partinvoiceid <> h.partinvoiceid
		AND ba.STATUS = 2
	),
oobmissingdiscountpartinvoice
AS (
	SELECT businessactionid
	FROM (
		SELECT ba.businessactionid
		FROM papartinvoiceline pi
		INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
		INNER JOIN mabusinessaction ba ON ba.documentid = pi.partinvoiceid
		INNER JOIN (
			SELECT pi.partinvoiceid
			FROM papartinvoice pi
			INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
			INNER JOIN (
				SELECT SUM((qtyspecialorder * adjustmentprice) / 10000) AS amt,
					partinvoiceid
				FROM papartinvoiceline
				GROUP BY partinvoiceid
				) soamt ON soamt.partinvoiceid = pi.partinvoiceid
			WHERE pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
			) v1 ON v1.partinvoiceid = pi.partinvoiceid
		INNER JOIN (
			SELECT SUM(debitamt - creditamt) AS oob,
				bai.businessactionid
			FROM mabusinessactionitem bai
			INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
			WHERE ba.documenttype = 1001
				AND ba.STATUS = 2
			GROUP BY bai.businessactionid
			) oob ON oob.businessactionid = ba.businessactionid
		INNER JOIN (
			SELECT SUM(depositapplied) AS applied,
				partinvoiceid
			FROM papartinvoiceline
			GROUP BY partinvoiceid
			) dep ON dep.partinvoiceid = pi.partinvoiceid
		INNER JOIN (
			SELECT pi.partinvoiceid
			FROM papartinvoice pi
			INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
			INNER JOIN (
				SELECT sum((qtyspecialorder * adjustmentprice) / 10000) AS amt,
					partinvoiceid
				FROM papartinvoiceline
				GROUP BY partinvoiceid
				) soamt ON soamt.partinvoiceid = pi.partinvoiceid
				AND pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
			) soa ON soa.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoice pin on pi.partinvoiceid = pin.partinvoiceid
		INNER JOIN cosaletype st ON st.saletypeid = pin.handlingsaletypeid
		WHERE ba.documenttype = 1001
			AND ba.STATUS = 2
			AND dep.applied <> oob.oob
			AND CASE 
				WHEN st.usagecode = 7
					AND pin.invoicehandlingamt + pin.specialorderhandling != 0
					THEN 0
				ELSE 1
				END = 1
		GROUP BY ba.businessactionid
		) data
	GROUP BY businessactionid
	),
oobnonpaypartinvoice
AS (
	SELECT ba.businessactionid
	FROM papartinvoice pi
	INNER JOIN cosaletype st ON st.saletypeid = pi.handlingsaletypeid
		AND st.usagecode = 7
	INNER JOIN mabusinessaction ba ON ba.documentid = pi.partinvoiceid
	INNER JOIN (
		SELECT bai.businessactionid,
			sum(debitamt - creditamt) AS oobamt
		FROM mabusinessactionitem bai
		GROUP BY bai.businessactionid
		) oob ON oob.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
		AND pi.invoicehandlingamt + specialorderhandling != 0
		AND pi.invoicehandlingamt + specialorderhandling = oob.oobamt
	),
taxoobpartinvoice -- https://lightspeeddms.atlassian.net/browse/EVO-17198
AS (
	SELECT ba.businessactionid
	FROM papartinvoice pi
	INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = pi.partinvoiceid
	INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
	INNER JOIN mabusinessaction ba ON ba.invoicenumber = pi.partinvoicenumber::TEXT
	INNER JOIN maedata ON maedata.businessactionid = ba.businessactionid -- Join on the OOB cte so we can validate fixing this fixes the oob amount
	WHERE ba.documenttype = 1001
		AND ba.STATUS = 2
		AND (piti.taxamount - pite.taxamount) = maedata.oobamt
	GROUP BY ba.businessactionid
	),
armopinternalinvoice
AS (
	SELECT ba.businessactionid
	FROM mabusinessaction ba
	INNER JOIN mabusinessactionerror bae using (businessactionid)
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = ba.documentid
	INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = pi.commoninvoiceid
	WHERE ba.STATUS = 2
		AND bae.errortext ilike 'No A/R Customer for Method of Payment %'
		AND pi.invoicetype = 1
		AND pi.majorunitid > 0
		AND cip.amount = 0
		AND pi.createdate BETWEEN '2020-10-01'
			AND '2020-12-19'
	GROUP BY ba.businessactionid
	),
oobmissingmoppartinvoice
AS (
	SELECT ba.businessactionid
	FROM papartinvoice pi
	INNER JOIN mabusinessaction ba ON ba.documentid = pi.partinvoiceid
	INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
	INNER JOIN cocommoninvoice ci ON ci.commoninvoiceid = pi.commoninvoiceid
	INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
	INNER JOIN (
		SELECT (sum(debitamt - creditamt) * - 1) AS oobamt,
			businessactionid
		FROM mabusinessactionitem
		GROUP BY businessactionid
		) sums ON sums.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
		AND pi.invoicetype NOT IN (2, 3)
		AND sums.oobamt = pit.soldnowsubtotal
	GROUP BY ba.businessactionid
	HAVING sum(cip.amount) = 0
	),
oobwrongmopamountrepairorder
AS (
	SELECT ba.businessactionid
	FROM cocommoninvoicepayment cip
	INNER JOIN cocommoninvoice ci ON ci.commoninvoiceid = cip.commoninvoiceid
	INNER JOIN serepairorder ro ON ro.repairorderid = ci.documentid
	INNER JOIN serototals rt ON rt.roid = ro.repairorderid
	INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
	WHERE ba.STATUS = 2
		AND ro.storeid = ba.storeid
	GROUP BY roid,
		ba.businessactionid
	HAVING sum(cip.amount) != rt.rototalnw
	),
dealoobins
AS (
	SELECT ba.businessactionid
	FROM sadealfinalization df
	INNER JOIN sadeal d ON d.dealid = df.dealid
	INNER JOIN mabusinessaction ba ON ba.documentid = df.dealfinalizationid
	INNER JOIN (
		SELECT dealid,
			sum(price) AS insprice
		FROM sadealinsurancetype
		WHERE price != 0
		GROUP BY dealid
		) di ON di.dealid = d.dealid
	INNER JOIN cocommoninvoice ci ON ci.invoicenumber::VARCHAR = ba.invoicenumber
		AND ci.storeid = ba.storeid
	INNER JOIN (
		SELECT commoninvoiceid,
			sum(amount) * - 1 AS amts,
			count(commoninvoiceid) AS pymts,
			array_agg(commoninvoicepaymentid) AS cipids
		FROM cocommoninvoicepayment
		GROUP BY commoninvoiceid
		) cip ON cip.commoninvoiceid = ci.commoninvoiceid
	INNER JOIN (
		SELECT businessactionid,
			sum(debitamt - creditamt) * - 1 AS oob
		FROM mabusinessactionitem
		GROUP BY businessactionid
		) oob ON oob.businessactionid = ba.businessactionid
	WHERE ba.STATUS = 2
		AND (amts + oob.oob) / 2 = di.insprice
		AND ((amts + oob.oob) * - 1) / 2 = d.balancetofinance
	),
oobwrongamtsalesdeal
AS (
	SELECT b.businessactionid
	FROM sadeal A
	INNER JOIN sadealfinalization df ON df.dealid = a.dealid
	INNER JOIN mabusinessaction B ON b.documentid = df.dealfinalizationid
	INNER JOIN cocommoninvoicepayment C ON C.commoninvoiceid = df.commoninvoiceid
	WHERE B.STATUS = 2
	GROUP BY a.balancetofinance,
		c.commoninvoicepaymentid,
		b.businessactionid
	HAVING count(C.commoninvoicepaymentid) = 1
		AND c.amount != a.balancetofinance
	),
taxroundingrepairorder -- heavily modified 13501 NOT VERIFIED TO WORK yet 
AS (
	SELECT businessactionid
	FROM (
		SELECT ba.businessactionid
		FROM serepairordertaxentity e
		INNER JOIN serepairordertaxitem i ON e.repairordertaxitemid = i.repairordertaxitemid
		INNER JOIN serepairorder ro ON ro.repairorderid = i.repairorderid
		INNER JOIN mabusinessaction ba ON ba.documentid = ro.repairorderid
		WHERE ba.STATUS = 2
		GROUP BY ba.businessactionid,
			i.repairordertaxitemid
		HAVING i.taxamount != ROUND(SUM(e.taxamount), - 2)
			AND SUM(e.taxamount) != SUM(ROUND(e.taxamount, - 2))
		) error
	GROUP BY businessactionid
	)
SELECT maedata.documentnumber AS docnumber,
	maedata.doctype AS documenttype,
	maedata.errorstatus AS STATUS,
	maedata.docdate AS DATE,
	s.storename || ', Id:' || s.storeid::VARCHAR AS storeandstoreid,
	ba.documentid,
	CASE 
		WHEN missingmae.businessactionid IS NOT NULL
			THEN 'EVO-20030 Document Missing from MAE List | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN schedacctnotvalidar.businessactionid IS NOT NULL
			THEN 'EVO-38097 Scheduled Not Valid for A/R Customerid XXXXX PSS Items | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN miscinvnonarmop.businessactionid IS NOT NULL
			THEN 'EVO-33866 Scheduled Not Valid for A/R Customerid XXXXX Misc Receipt | T2'
		ELSE ''
		END || CASE 
		WHEN dealarglaccount.businessactionid IS NOT NULL
			THEN 'EVO-3087 Scheduled Account XXXX Not Valid for A/R Customerid XXXXX Sales Deal | T1 Front End Fix, See CR for info'
		ELSE ''
		END || CASE 
		WHEN earop.businessactionid IS NOT NULL
			THEN 'EVO-26911 Error Accessing RO Part Category | T2'
		ELSE ''
		END || CASE 
		WHEN earol.businessactionid IS NOT NULL
			THEN 'EVO-18036 Error Accessing RO Labor Category | T2'
		ELSE ''
		END || CASE 
		WHEN erroraccmiscsaletype.businessactionid IS NOT NULL
			THEN 'EVO-39691 Error Accessing RO Misc Charge Saletype'
		ELSE ''
		END || CASE 
		WHEN eapicat.businessactionid IS NOT NULL -- Error Accessing on Part Invoice // Verified Diag To Work
			THEN 'EVO-13570 Error Accessing Part Invoice Category | T2'
		ELSE ''
		END || CASE 
		WHEN earpcat.businessactionid IS NOT NULL -- Error Accessing On Part Receiving Document
			THEN 'EVO-31748 Error Accessing Receiving Document Part Category | T2'
		ELSE ''
		END || CASE 
		WHEN partinvoicescheduledmu.businessactionid IS NOT NULL -- Error Accessing On Part Receiving Document
			THEN 'EVO-14901 Part Category Has MU Scheduled Inventory Account | T2'
		ELSE ''
		END || CASE 
		WHEN analysispending.businessactionid IS NOT NULL -- Analysis Pending On Part Receiving Document
			THEN 'EVO-29301 Analysis Pending on Part Receiving Document | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN invalidglnonpayro.businessactionid IS NOT NULL -- Invalid GL For Non-Pay Job on Repair Order
			THEN 'EVO-34114 Invalid GL Account ID = 0 Non-Pay Repair Order | T2'
		ELSE ''
		END ||
	/*	CASE removing this because it's brokebn 
		WHEN invalidgldealandinvoice.businessactionid IS NOT NULL -- Invalid GL for MOP on Sales Deal or Part Invoice // UNABLE TO DIFFERENTIATE BETWEEN DEPOSIT APPLIED AND NO PAYMENT
			THEN 'EVO-35010'
		ELSE 'N/A'
		END AS invalidgldealandinvoice, */
	CASE 
		WHEN invalidglclaimsubmission.businessactionid IS NOT NULL
			THEN 'EVO-29577 Invalig GL Account ID = 0 Warranty Claim Submission | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN taxidrental.businessactionid IS NOT NULL -- Rental Reservation with bad taxid
			THEN 'EVO-12777 Could not Locate Tax Entity Reservation | T2'
		ELSE ''
		END || CASE 
		WHEN longvaltax.businessactionid IS NOT NULL
			THEN 'EVO-37225 Invalid Monetary Fraction XXX Document, Long Value Tax | T2'
		ELSE ''
		END || CASE 
		WHEN taxiddeal1.businessactionid IS NOT NULL -- Deal with bad taxid linked to diff store
			THEN 'EVO-9836 Error Getting Unit Tax Information | T2'
		ELSE ''
		END || CASE 
		WHEN taxiddeal2.businessactionid IS NOT NULL -- Deal with bad taxid linked to diff store
			THEN 'EVO-26472 Error Updating Accounting | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN taxidpartinvoice1.businessactionid IS NOT NULL -- part invoice tax entity with bad taxentityid https://lightspeeddms.atlassian.net/browse/EVO-35995
			THEN 'EVO-35995 Could Not Locate Tax Entity XXX | T2'
		ELSE ''
		END || CASE 
		WHEN tradedealid.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-22520 Trade Deal ID Issue Diag Not Verified | N/A'
		ELSE ''
		END || CASE 
		WHEN dealunitid1.businessactionid IS NOT NULL -- MU with bad dealunitid // NOT TESTED, PLEASE CORRECT IF NOT WORKING
			THEN 'EVO-21635 Error Accessing, RO Unit with Bad Deal ID | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN oobdupepartinvoice.businessactionid IS NOT NULL -- Tested and confirmed Duplicate Part invoice / SO
			THEN 'EVO-36594 Duplicate Part Invoice / SO | T2'
		ELSE ''
		END || CASE 
		WHEN oobmissingdiscountpartinvoice.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-20828 Part Invoice OOB Missing Discounts on Lines | T2'
		ELSE ''
		END || CASE 
		WHEN oobnonpaypartinvoice.businessactionid IS NOT NULL -- Semi-verified
			THEN 'EVO-39247 Part Invoice OOB Non-Pay Handling Amt | T2'
		ELSE ''
		END || CASE 
		WHEN armopinternalinvoice.businessactionid IS NOT NULL
			THEN 'EVO-31066 Internal Invoice Using AR MOP | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN taxoobpartinvoice.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-17198 Part Invoice OOB Tax Not Rounded Properly | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN oobmissingmoppartinvoice.businessactionid IS NOT NULL
			THEN 'EVO-39505 Invoice OOB paid with Blank Method of Payment 0$ | T2'
		ELSE ''
		END || CASE 
		WHEN oobwrongmopamountrepairorder.businessactionid IS NOT NULL -- Invalid GL for MOP on Sales Deal or Part Invoice
			THEN 'EVO-30796 Repair Order OOB Method of Payment Amount Incorrect | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN dealoobins.businessactionid IS NOT NULL -- VERIFIED
			THEN 'EVO-24051 Deal OOB insurance Forces Negative Balance to Finance | T2'
		ELSE ''
		END || CASE 
		WHEN oobwrongamtsalesdeal.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-31125 Sales Deal OOB Method of Payment != Balance to Finance | T1 Preapproved'
		ELSE ''
		END || CASE 
		WHEN taxroundingrepairorder.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-13501 Tax Entity not rounded Repair Order | T1 Preapproved'
		ELSE ''
		END AS issue_description_and_cr,
	CASE 
		WHEN maedata.oobamt != 0
			THEN maedata.oob
		ELSE 'N/A'
		END AS balancestate,
	maedata.txt AS errormessage
FROM mabusinessaction ba
LEFT JOIN maedata ON maedata.businessactionid = ba.businessactionid
LEFT JOIN costore s ON s.storeid = ba.storeid
LEFT JOIN erroraccropart earop ON earop.businessactionid = ba.businessactionid -- EVO-26911 RO Part with Bad Categoryid
LEFT JOIN erroraccrolabor earol ON earol.businessactionid = ba.businessactionid -- EVO-18036 RO Labor with Bad Categoryid
LEFT JOIN erroraccpicat eapicat ON eapicat.businessactionid = ba.businessactionid -- EVO-13570 Part Invoice Line with Bad Categoryid
LEFT JOIN erroraccreceivepart earpcat ON earpcat.businessactionid = ba.businessactionid -- EVO-31748 Part Receiving Doc with Bad Categoryid
LEFT JOIN erroraccmiscsaletype ON erroraccmiscsaletype.businessactionid = ba.businessactionid -- EVO-39691 RO with bad misc item categoryid
LEFT JOIN partinvoicescheduledmu ON partinvoicescheduledmu.businessactionid = ba.businessactionid -- EVO-14901 Part on Invoice with MU Category
LEFT JOIN missingmae ON missingmae.businessactionid = ba.businessactionid
LEFT JOIN analysispending ON analysispending.businessactionid = ba.businessactionid
LEFT JOIN invalidglnonpayro ON invalidglnonpayro.businessactionid = ba.businessactionid
LEFT JOIN invalidgldealandinvoice ON invalidgldealandinvoice.businessactionid = ba.businessactionid
LEFT JOIN invalidglclaimsubmission ON invalidglclaimsubmission.businessactionid = ba.businessactionid -- EVO-29577
LEFT JOIN schedacctnotvalidar ON schedacctnotvalidar.businessactionid = ba.businessactionid -- EVO-38907 AR Sched Acct not valid for MOP
LEFT JOIN miscinvnonarmop ON miscinvnonarmop.businessactionid = ba.businessactionid -- EVO-33866 AR Sched Invalid for Misc Receipt
LEFT JOIN dealarglaccount ON dealarglaccount.businessactionid = ba.businessactionid -- EVO-3087
LEFT JOIN taxidrental ON taxidrental.businessactionid = ba.businessactionid -- EVO-12777 Rental Reservation with bad rental posting taxid
LEFT JOIN longvaltax ON longvaltax.businessactionid = ba.businessactionid -- EVO-37225 long val tax not rounded
LEFT JOIN taxiddeal1 ON taxiddeal1.businessactionid = ba.businessactionid -- EVO-9836 Deal Unit tax with invalid taxentityid
LEFT JOIN taxiddeal2 ON taxiddeal2.businessactionid = ba.businessactionid -- EVO-26472 Deal Unit Tax with taxentityid from other store
LEFT JOIN taxidpartinvoice1 ON taxidpartinvoice1.businessactionid = ba.businessactionid -- EVO-35995 
LEFT JOIN tradedealid ON tradedealid.businessactionid = ba.businessactionid -- EVO-22520 Deal Trade MAE with invalid tradedealid
LEFT JOIN dealunitid1 ON dealunitid1.businessactionid = ba.businessactionid -- EVO-21635 Deal Unit ID linking to invalid dealunit
LEFT JOIN dealoobins ON dealoobins.businessactionid = ba.businessactionid -- EVO-24051
LEFT JOIN oobdupepartinvoice ON oobdupepartinvoice.businessactionid = ba.businessactionid
LEFT JOIN oobmissingdiscountpartinvoice ON oobmissingdiscountpartinvoice.businessactionid = ba.businessactionid -- EVO-20828
LEFT JOIN oobnonpaypartinvoice ON oobnonpaypartinvoice.businessactionid = ba.businessactionid -- EVO-39247
LEFT JOIN taxoobpartinvoice ON taxoobpartinvoice.businessactionid = ba.businessactionid -- EVO-17198 taxes oob compared to tax entity amounts
LEFT JOIN oobmissingmoppartinvoice ON oobmissingmoppartinvoice.businessactionid = ba.businessactionid
LEFT JOIN armopinternalinvoice ON armopinternalinvoice.businessactionid = ba.businessactionid -- EVO-31066
LEFT JOIN oobwrongmopamountrepairorder ON oobwrongmopamountrepairorder.businessactionid = ba.businessactionid -- EVO-30796 Mop Amount less than Amount to Collect on RO
LEFT JOIN oobwrongamtsalesdeal ON oobwrongamtsalesdeal.businessactionid = ba.businessactionid -- EVO-31125
LEFT JOIN taxroundingrepairorder ON taxroundingrepairorder.businessactionid = ba.businessactionid
WHERE ba.STATUS IN (2, 4)
ORDER BY s.storename ASC,
	documentdate DESC
