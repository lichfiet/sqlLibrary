WITH searchdata
AS (
	-- INSTRUCTIONS
	---------------------------------------------------------------------------------------
	--
	-- 	Replace the CHANGE ME with one or more document numbers in a comma separated list,
	--  you can do this with either the document numbers (the first [CHANGE ME]) or you,
	--  can search using invoice numbers (the second [CHANGE ME]). Leaving them as is will
	--  search for all management activities
	--
	---------------------------------------------------------------------------------------
	--
	-- /* You can add multiple values separate by commas ex. ('123', '456', '789') */
	-- /* Or, you can search for one or the other invoice number/documentnumber ex. ('123) */
	--
	SELECT
		--
		-- SEARCH BY DOCUMENTNUMBER
		ARRAY ['CHANGE_ME'] AS documentnumbers,
		--
		-- SEARCH BY INVOICE NUMBER
		ARRAY ['CHANGE_ME'] AS invoicenumbers
		--
		---------------------------------------------------------------------------------------
		--
	),
maedata
AS (
	SELECT ba.businessactionid,
		ba.documentnumber,
		ba.invoicenumber,
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
		sum(bai.debitamt - creditamt) AS rawoobamt,
		CASE 
			WHEN sum(debitamt - creditamt) = 0
				THEN 'In Balance'
			ELSE 'Out of Balance!'
			END AS oob,
		left(string_agg(errortext, ''), 70) || '...' AS txt,
		string_agg(errortext, '') AS rawtxt,
		ba.STATUS AS rawstatus,
		ba.businessactionid AS rawbusinessactionid,
		ba.storeid AS rawstoreid,
		ba.documentid AS rawdocumentid,
		ba.documentsubid AS rawdocumentsubid,
		ba.documentdate AS rawdocumentdate,
		ba.documenttype AS rawdocumenttype,
		ba.storeid,
		s.storename
	FROM mabusinessaction ba
	LEFT JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	LEFT JOIN mabusinessactionerror bae ON bae.businessactionid = ba.businessactionid
	LEFT JOIN costore s ON s.storeid = ba.storeid
	LEFT JOIN searchdata ON searchdata.documentnumbers [1] != 'CHANGE_ME'
		OR searchdata.invoicenumbers [1] != 'CHANGE_ME'
	WHERE ba.STATUS IN (2, 4)
		AND (
			s.istraining = false
			OR s.storeid IS NULL
			)
		AND (
			CASE 
				WHEN searchdata.documentnumbers IS NOT NULL
					AND ba.documentnumber::VARCHAR = ANY (searchdata.documentnumbers)
					OR ba.invoicenumber::VARCHAR = ANY (searchdata.invoicenumbers)
					THEN 1
				WHEN searchdata.documentnumbers IS NULL
					THEN 1
				ELSE 0
				END
			) = 1
	GROUP BY ba.businessactionid,
		documentnumber,
		STATUS,
		documenttype,
		s.storename
	),
paymentinfo
AS (
	SELECT ba.businessactionid,
		count(cip.commoninvoicepaymentid) AS mopcount,
		sum(cip.amount) AS mopamount,
		array_agg(cip.description) AS mopdescriptionsarr,
		string_agg(cip.description, '') AS mopdescriptionsstr,
		array_agg(cip.amount) AS mopamountarr,
		array_agg(cip.methodofpaymentid) AS mopids,
		array_agg(cip.arcustomerid) AS arcustomerids
	FROM maedata ba
	INNER JOIN cocommoninvoice ci ON ci.invoicenumber::VARCHAR = ba.invoicenumber
	INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
	GROUP BY ba.businessactionid
	),
negativedealtax -- NEEDS OPTIMIZATION, combine with one below and do a custom casewhen and then update the casewhen for issue description
AS (
	SELECT businessactionid
	FROM sadeal d
	INNER JOIN sadealunit du using (dealid)
	INNER JOIN sadealunittax dut using (dealunitid)
	INNER JOIN sadealfinalization df ON df.dealid = du.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = df.dealfinalizationid
	WHERE dut.taxpct <> 0
		AND dut.taxableamt <> 0
		AND dut.taxamt = 0
		AND df.actualfinalizationdate < '2024-05-20 T00:00:00+00:00'
		AND ba.rawSTATUS = 2
	GROUP BY ba.businessactionid,
		ba.rawoobamt
	HAVING SUM(ROUND((ROUND(dut.taxableamt::FLOAT / 10000) * (dut.taxpct::FLOAT / 1000000))::NUMERIC * 10000, 0)) != sum(dut.taxamt)
	),
negativedealtaxnew -- NEEDS OPTIMIZATION
AS (
	SELECT businessactionid
	FROM sadeal d
	INNER JOIN sadealunit du using (dealid)
	INNER JOIN sadealunittax dut using (dealunitid)
	INNER JOIN sadealfinalization df ON df.dealid = du.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = df.dealfinalizationid
	WHERE dut.taxpct <> 0
		AND dut.taxableamt <> 0
		AND df.actualfinalizationdate > '2024-05-20 T00:00:00+00:00'
		AND dut.taxamt = 0
		AND ba.rawSTATUS = 2
	GROUP BY ba.businessactionid,
		ba.rawoobamt
	HAVING SUM(ROUND((ROUND(dut.taxableamt::FLOAT / 10000) * (dut.taxpct::FLOAT / 1000000))::NUMERIC * 10000, 0)) != sum(dut.taxamt)
	),
schedacctnotvalidar
AS (
	SELECT ma.businessactionid -- optimized
	FROM maedata ma
	INNER JOIN paymentinfo pyi ON pyi.businessactionid = ma.businessactionid
	INNER JOIN comethodofpayment mop ON mop.methodofpaymentid = ANY (pyi.mopids)
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = mop.glacct
	WHERE ma.rawSTATUS = 2
		AND ma.rawtxt ilike '%Not Valid%'
		AND 0 != ALL (pyi.arcustomerids)
	GROUP BY ma.businessactionid
	HAVING sum(coa.schedule) = 0
	),
miscinvnonarmop -- probably optimized
AS (
	SELECT ma.businessactionid
	FROM maedata ma
	INNER JOIN mabusinessactionitem mai using (businessactionid)
	INNER JOIN cocommoninvoice ci ON ci.invoicenumber::TEXT = ma.invoicenumber::TEXT
	INNER JOIN cocommoninvoicepayment cip using (commoninvoiceid)
	INNER JOIN comiscreceipttype mrt ON mrt.glacct = mai.accountid
	INNER JOIN pamiscinvoice mi ON mi.miscrectype = mrt.miscreceipttypeid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = mai.accountid
	WHERE rawSTATUS = 2
		AND coa.schedule = 0
		AND mi.arcustomerid > 0
	GROUP BY ma.businessactionid
	),
dealarglaccount -- NEEDS OPTIMIZATION
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
		FROM maedata ba
		INNER JOIN maedata ba1 USING (documentnumber)
		WHERE ba.rawSTATUS = 2
			AND ba.rawdocumenttype = 3006
			AND ba1.rawdocumenttype = 3001
			AND ba1.invoicenumber < ba.invoicenumber
			AND ba.rawstoreid = ba1.storeid
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
erroraccropart -- NEEDS OPTIMIZATION
AS (
	SELECT ba.businessactionid
	FROM serepairorderpart rp
	INNER JOIN papart p ON p.partid = rp.partid
	INNER JOIN serepairorderjob rj ON rj.repairorderjobid = rp.repairorderjobid
	INNER JOIN serepairorderunit ru ON ru.repairorderunitid = rj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = ru.repairorderid
	INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
	INNER JOIN cocategory c ON p.categoryid = c.categoryid
	WHERE ba.rawSTATUS = 2
		AND c.storeid != rp.storeid
	GROUP BY ba.businessactionid
	),
erroraccrolabor -- NEEDS OPTIMIZATION
AS (
	SELECT businessactionid
	FROM serepairorderlabor rol
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rol.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
	INNER JOIN cocategory badcat ON badcat.categoryid = rol.categoryid
		AND badcat.storeid != rol.storeid
	INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
	WHERE ba.rawstatus = 2
	GROUP BY businessactionid
	),
erroraccrolabor2 -- NEEDS OPTIMIZATION
AS (
	SELECT ba.businessactionid -- this one probably needs a different CR but it has to do with the warranty company having a diff storeid for freight
	FROM serepairorder ro
	INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
	INNER JOIN serepairorderunit rou ON rou.repairorderid = ro.repairorderid
	INNER JOIN serepairorderjob roj ON roj.repairorderunitid = rou.repairorderunitid
	INNER JOIN sewarrantyclaim wc ON wc.repairorderjobid = roj.repairorderjobid
	INNER JOIN cowarrantycompany warrcom ON warrcom.warrantycompanyid = wc.warrantycompanyid
	INNER JOIN cocategory currcat ON currcat.categoryid = warrcom.freightcategoryid
		AND currcat.storeid != warrcom.storeid
	WHERE ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
erroraccmiscsaletype -- NEEDS OPTIMIZATION
AS (
	SELECT ba.businessactionid
	FROM serepairorder ro
	INNER JOIN cosaletype st ON st.saletypeid = ro.miscitemsaletypeid
		AND ro.storeid != st.storeid
	INNER JOIN maedata ba ON ba.rawstatus = 2
		AND ba.rawdocumentid = ro.repairorderid
	GROUP BY ba.businessactionid
	),
erroraccpicat -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoiceline pi ON pi.partinvoiceid = ba.rawdocumentid
	INNER JOIN cocategory c ON c.categoryid = pi.categoryid
		AND c.storeid != pi.storeid
	WHERE ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
erroraccreceivepart -- NEEDS OPTIMIZATION // turn into separate queries/CTEs, and re-write them
AS (
	SELECT businessactionid
	FROM (
		SELECT ba.businessactionid
		FROM papartadjustment pa
		INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = pa.receivingdocumentid
		LEFT JOIN maedata ba ON ba.rawdocumentid = rd.receivingdocumentid
		INNER JOIN cocategory c ON pa.categoryid = c.categoryid
		WHERE ba.rawstatus = 2
			AND ba.rawdocumentid IS NOT NULL
			AND c.storeid != pa.storeid
		GROUP BY ba.businessactionid
		
		UNION
		
		SELECT ba.businessactionid
		FROM papurchaseorder pa
		INNER JOIN papartadjustment ph ON ph.referenceid = pa.purchaseorderid
		INNER JOIN pareceivingdocument rd ON ph.receivingdocumentid = rd.receivingdocumentid
		INNER JOIN papartshipment ps ON ps.partshipmentid = ph.partshipmentid
		INNER JOIN papart p ON p.partid = ph.partid
		INNER JOIN maedata ba ON rd.receivingdocumentid = ba.rawdocumentid
		WHERE ba.rawstatus = 2
			AND (
				rd.storeid != p.storeid
				OR rd.storeidluid != p.storeidluid
				)
		GROUP BY ba.businessactionid
		) AS subquery
	GROUP BY businessactionid
	),
partinvoicescheduledmu1
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoiceline pil ON ba.rawdocumentid = pil.partinvoiceid
	INNER JOIN papartinvoice pi ON pil.partinvoiceid = pi.partinvoiceid
	INNER JOIN cocategory c ON pil.categoryid = c.categoryid
	INNER JOIN glchartofaccounts coa ON c.glinventory = coa.acctdeptid
	WHERE coa.schedule != 0
		AND ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
partinvoicescheduledmu -- NEEDS OPTIMIZATION // turn into separate CTEs and re-write
AS (
	SELECT ba.businessactionid
	FROM papartadjustment pa
	INNER JOIN pareceivingdocument rd ON rd.receivingdocumentid = pa.receivingdocumentid
	INNER JOIN cocategory c ON c.categoryid = pa.categoryid
	INNER JOIN maedata ba ON ba.rawdocumentid = rd.receivingdocumentid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	WHERE coa.schedule != 0
		AND ba.rawstatus = 2
	GROUP BY ba.businessactionid
	
	UNION
	
	SELECT ba.businessactionid
	FROM serepairorderpart rop
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rop.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN serepairorder ro ON ro.repairorderid = rou.repairorderid
	INNER JOIN cocategory c ON c.categoryid = rop.categoryid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
	WHERE coa.schedule != 0
		AND ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
partinvoicemubadsaletype -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoiceline pil ON pil.partinvoiceid = ba.rawdocumentid
	LEFT JOIN cosaletype st ON st.saletypeid = pil.saletypeid
	WHERE ba.rawstatus = 2
		AND st.usagecode <> 2
		AND ba.rawtxt ilike '%Invalid Usage Code%'
	GROUP BY businessactionid
	),
subletcloseoutscheduledmu -- NEEDS OPTIMIZATION
AS (
	SELECT ba.businessactionid
	FROM sesubletcloseout sc
	INNER JOIN serepairordersublet rs ON rs.repairordersubletid = sc.subletlaborid
	INNER JOIN serepairorderjob roj ON roj.repairorderjobid = rs.repairorderjobid
	INNER JOIN serepairorderunit rou ON rou.repairorderunitid = roj.repairorderunitid
	INNER JOIN cocategory c ON c.categoryid = sc.categoryid
	INNER JOIN glchartofaccounts coa ON coa.acctdeptid = c.glinventory
	INNER JOIN maedata ba ON ba.rawdocumentid = sc.subletcloseoutid
		OR ba.rawdocumentid = rou.repairorderid
	WHERE coa.schedule != 0
		AND ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
analysispending -- NEEDS OPTIMIZATION // SMALL UPDATE, join on maedata CTE furst
AS (
	SELECT ba.businessactionid
	FROM papartadjustment pa
	INNER JOIN maedata ba ON ba.rawdocumentid = pa.receivingdocumentid
	LEFT JOIN papartshipment ps ON ps.partshipmentid = pa.partshipmentid
	WHERE ps.partshipmentid IS NULL
		AND ba.rawstatus = 4
		AND ba.rawdocumenttype = 1007
	),
invalidglnonpayro -- NEEDS OPTIMIZATION // join on maedata first
AS (
	SELECT ma.businessactionid
	FROM serepairorderjob roj
	INNER JOIN serepairorderunit rou using (repairorderunitid)
	INNER JOIN serepairorder ro using (repairorderid)
	INNER JOIN cosaletype st ON st.saletypeid = roj.saletypeid
	INNER JOIN maedata ma ON ma.rawdocumentid = ro.repairorderid
	WHERE isnonpayjob = 1
		AND st.usagecode NOT IN (5, 7)
		AND ma.rawstatus = 2
	GROUP BY ma.businessactionid
	),
invalidglblankmopinvoice
AS (
	SELECT b.businessactionid
	FROM maedata b
	INNER JOIN papartinvoice p ON p.partinvoiceid = b.rawdocumentid
		AND p.invoicetype NOT IN (2, 3)
	INNER JOIN paymentinfo pi ON pi.businessactionid = b.businessactionid
	WHERE b.rawSTATUS = 2
		AND pi.mopdescriptionsstr = ''
		AND p.partinvoiceid IS NOT NULL
		AND pi.mopamount != 0
		AND b.rawoobamt != 0
	GROUP BY b.businessactionid
	),
invalidglblankmopdeal -- potentially fixed, might needs to add something for insurance info or break these out into their own CTEs
AS (
	SELECT b.businessactionid
	FROM maedata b
	INNER JOIN sadealfinalization df ON df.dealfinalizationid = b.rawdocumentid
	INNER JOIN sadeal d ON df.dealid = d.dealid
	INNER JOIN paymentinfo pi ON pi.businessactionid = b.businessactionid
	WHERE b.rawSTATUS = 2
		AND pi.mopdescriptionsstr = ''
		AND df.dealfinalizationid IS NOT NULL
		AND d.balancetofinance != 0 -- fix me maybe to include insurance info
		AND pi.mopamount != 0
		AND b.rawoobamt != 0
	GROUP BY b.businessactionid
	),
invalidglclaimsubmission -- NEEDS OPTIMIZATION // small fix, move the AND clauses up into the joins if possible to eliminate extra joins
AS (
	SELECT ba.businessactionid AS businessactionid
	FROM maedata ba
	INNER JOIN sewarrantysubmissioncredit wsc ON wsc.warrantysubmissioncreditid = ba.rawdocumentid
	INNER JOIN sewarrantyclaimcredit using (warrantysubmissioncreditid)
	INNER JOIN sewarrantyclaim using (warrantyclaimid)
	INNER JOIN serepairorderjob roj using (repairorderjobid)
	INNER JOIN cosaletype st ON st.saletypeid = roj.saletypeid
	WHERE ba.rawstatus = 2
		AND st.usagecode = 5
		AND ba.rawdocumenttype = 2003
		AND roj.warrantycompanyid <> wsc.warrantycompanyid
	GROUP BY ba.businessactionid
	),
taxidrental -- NEEDS OPTIMIZATION // too many joins, needs to be reworked somehow
AS (
	SELECT ba.businessactionid
	FROM rerentalpostingtaxdetail rptd
	INNER JOIN rerentalpostingtax rpt ON rpt.rentalpostingtaxid = rptd.rentalpostingtaxid
	INNER JOIN rerentalpostingitem rpi ON rpi.rentalpostingid = rpt.rentalpostingid
	INNER JOIN rerentalposting rp ON rp.rentalpostingid = rpi.rentalpostingid
	INNER JOIN maedata ba ON ba.documentnumber = rp.documentnumber
	INNER JOIN cotaxcategory tc ON tc.taxcategorydescription = rpt.description
		AND tc.storeid = rpt.storeid
	INNER JOIN cotax t ON t.taxcategoryid = tc.taxcategoryid
	LEFT JOIN cotax t2 ON t2.taxid = rptd.taxentityid
	WHERE ba.rawstatus = 2
		AND t2.taxid IS NULL
	GROUP BY ba.businessactionid
	),
taxiddeal1 -- NEEDS OPTIMIZATION // select from maedata first, then join on deal finalization, etc
AS (
	SELECT ba.businessactionid
	FROM sadealunittax dut
	LEFT JOIN cotax t ON t.taxid = dut.taxentityid
	INNER JOIN cotaxcategory tc ON tc.taxcategorydescription = dut.taxcategorydescription
	INNER JOIN cotax t2 ON t2.taxcategoryid = tc.taxcategoryid
	INNER JOIN sadealunit du ON du.dealunitid = dut.dealunitid
	INNER JOIN sadeal d ON d.dealid = du.dealid
	INNER JOIN sadealfinalization f ON f.dealid = d.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = f.dealfinalizationid
	WHERE t.taxid IS NULL
		AND tc.storeid = dut.storeid
		AND ba.rawstatus = 2
	GROUP BY ba.businessactionid
	),
taxiddeal2 -- NEEDS OPTIMIZATION // select from maedata first, then join on deal finalization, etc
AS (
	SELECT ba.businessactionid
	FROM sadeal d
	INNER JOIN sadealunit du ON du.dealid = d.dealid
	INNER JOIN cosaletype st ON st.saletypeid = du.saletypeid
		AND st.storeid = du.storeid
	INNER JOIN sadealunittax dut ON dut.dealunitid = du.dealunitid
	INNER JOIN cotax t ON t.taxid = dut.taxentityid
	INNER JOIN cotax t1 ON t1.description ilike dut.taxdescription
		AND t1.storeid = dut.storeid
	INNER JOIN cotaxcategory tc ON tc.taxcategoryid = t1.taxcategoryid
	INNER JOIN sadealfinalization df ON df.dealid = d.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = df.dealfinalizationid
	WHERE ba.rawSTATUS = 2
		AND t.storeid <> d.storeid
	GROUP BY ba.businessactionid
	),
dealtaxroundpenny -- NEEDS OPTIMIZATION // select from maedata first, then join on deal finalization, etc
AS (
	SELECT ba.businessactionid
	FROM sadealunittax dut
	INNER JOIN sadealunit du USING (dealunitid)
	INNER JOIN sadeal d USING (dealid)
	INNER JOIN sadealfinalization df ON df.dealid = d.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = df.dealfinalizationid
	WHERE ba.rawSTATUS = 2
		AND dut.storeid = d.storeid
		AND taxpct > 0
		AND abs(dut.taxamt) = (ROUND((((((dut.taxableamt) * (dut.taxpct::FLOAT / 1000000))) * 1)::INT) * 0.01) * 100) + 100
	),
dealunitbadsaletype -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN sadealfinalization df ON df.dealfinalizationid = ba.rawdocumentid
	INNER JOIN sadeal d ON d.dealid = df.dealid
	INNER JOIN sadealunit du ON d.dealid = du.dealid
	INNER JOIN cosaletype st ON st.saletypeid = du.saletypeid
	WHERE st.storeid <> du.storeid
	),
taxidpartinvoice1 -- optimized i think
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = ba.rawdocumentid
	INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
	LEFT JOIN cotax t ON t.taxid = pite.taxentityid
	LEFT JOIN cotax t1 ON t1.taxcategoryid = piti.taxcategoryid
	INNER JOIN cotaxcategory ct ON ct.taxcategoryid = piti.taxcategoryid
	WHERE ba.rawSTATUS = 2
		AND (
			t1.description = t.description
			AND t1.taxid <> t.taxid
			AND t1.taxid <> pite.taxentityid
			AND ct.taxcategoryid = t1.taxcategoryid
			OR pite.taxentityid IS NULL
			)
	GROUP BY partinvoicetaxentityid,
		ba.businessactionid
	),
longvaltax -- https://lightspeeddms.atlassian.net/browse/EVO-37225 -- NEEDS OPTIMIZATION // move around joins and break out into diff ctes
AS (
	SELECT ba.businessactionid
	FROM sadealadjustmenttax dat
	INNER JOIN sadealadjustment da ON da.dealadjustmentid = dat.dealadjustmentid
	INNER JOIN maedata ba ON ba.rawdocumentid = da.dealadjustmentid
	INNER JOIN maedata errortext ON errortext.businessactionid = ba.businessactionid
	WHERE ba.rawstatus = 2
		AND (
			errortext.txt ilike '%Tax Entity not rounded%'
			OR errortext.txt ilike '%Invalid Monetary Fraction%'
			)
	GROUP BY ba.businessactionid
	
	UNION
	
	SELECT ba.businessactionid
	FROM rerentalpostingtaxdetail rptd
	INNER JOIN rerentalpostingtax rpt ON rpt.rentalpostingtaxid = rptd.rentalpostingtaxid
	INNER JOIN rerentalposting rp ON rp.rentalpostingid = rpt.rentalpostingid
	INNER JOIN maedata ba ON ba.rawdocumentid = rp.rentalpostingid
	INNER JOIN maedata errortext ON errortext.businessactionid = ba.businessactionid
	WHERE ba.rawstatus = 2
		AND (
			errortext.txt ilike '%Tax Entity not rounded%'
			OR errortext.txt ilike '%Invalid Monetary Fraction%'
			)
	GROUP BY ba.businessactionid
	),
dealunitid1 -- https://lightspeeddms.atlassian.net/browse/EVO-21635 -- NEEDS OPTIMIZATION // move around joins
AS (
	SELECT ba.businessactionid
	FROM samajorunit mu
	LEFT JOIN sadealunit x ON x.majorunitid = mu.majorunitid
	LEFT JOIN sadealunit x1 ON x1.dealunitid = mu.dealunitid
	INNER JOIN sadeal d ON d.dealid = x.dealid
	INNER JOIN sadealfinalization df ON df.dealid = d.dealid
	INNER JOIN maedata ba ON ba.rawbusinessactionid = df.dealfinalizationid
	WHERE mu.STATE = 2
		AND (
			x.dealunitid != 0
			OR x.dealunitid != NULL
			)
		AND d.STATE = 5
		AND x1.dealunitid IS NULL
		AND ba.rawSTATUS = 2
	GROUP BY ba.businessactionid
	),
groupfordealunitid -- hypeer optimized
AS (
	SELECT businessactionid
	FROM maedata
	WHERE txt ilike '%Could not find the group for dealUnitID%'
	),
tradedealid -- optimized
AS (
	SELECT businessactionid
	FROM maedata ba
	LEFT JOIN sadealtrade dt ON dt.dealtradeid = ba.rawdocumentid
	WHERE ba.rawSTATUS = 2
		AND ba.rawdocumenttype = 3007
		AND dt.dealtradeid IS NULL
	),
mutransferstoreid -- NEEDS OPTIMIZATION // move around joins
AS (
	SELECT ba.businessactionid
	FROM samajorunit mu
	INNER JOIN samajorunittransfer mut ON mut.majorunitid = mu.majorunitid
	INNER JOIN maedata ba ON mut.majorunittransferid = ba.rawdocumentid
	INNER JOIN samajorunitsalescategory musc using (majorunitsalescategoryid)
	WHERE musc.storeid <> mu.storeid
		AND mu.STATE = 10
		AND ba.rawSTATUS = 2
	),
oobdupepartinvoice -- performance optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoiceline il ON ba.rawdocumenttype = 1001
		AND ba.rawdocumentid = il.partinvoiceid
	INNER JOIN paparthistory h ON h.partinvoiceid = il.partinvoiceid
	WHERE il.partinvoiceid <> h.partinvoiceid
		AND ba.rawSTATUS = 2
	),
oobmissingdiscountpartinvoice -- NEEDS OPTIMIZATION // did some mini optimization fixing the CTEs and subqueries, needs to do some more
AS (
	SELECT businessactionid
	FROM (
		WITH soamt AS (
				SELECT SUM((qtyspecialorder * adjustmentprice) / 10000) AS amt,
					partinvoiceid
				FROM maedata d
				INNER JOIN papartinvoiceline pil ON pil.partinvoiceid = d.rawdocumentid
				GROUP BY partinvoiceid
				)
		SELECT ba.businessactionid
		FROM maedata ba
		INNER JOIN paymentinfo pyi ON pyi.businessactionid = ba.businessactionid
			AND pyi.mopamount != 0
		INNER JOIN papartinvoiceline pi ON ba.rawdocumenttype = 1001
			AND ba.rawdocumentid = pi.partinvoiceid
		INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoicetaxitem piti ON piti.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoicetaxentity pite ON pite.partinvoicetaxitemid = piti.partinvoicetaxitemid
		INNER JOIN (
			SELECT pi.partinvoiceid
			FROM maedata d
			INNER JOIN papartinvoice pi ON d.rawdocumenttype = 1001
				AND pi.partinvoiceid = d.rawdocumentid
			INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
			INNER JOIN soamt ON soamt.partinvoiceid = pi.partinvoiceid
			WHERE pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
			) v1 ON v1.partinvoiceid = pi.partinvoiceid
		INNER JOIN (
			-- experiemental update
			SELECT SUM(depositapplied) AS applied,
				partinvoiceid
			FROM maedata ba
			INNER JOIN papartinvoiceline pil ON ba.rawdocumenttype = 1001
				AND pil.partinvoiceid = ba.rawdocumentid
			GROUP BY partinvoiceid
			) dep ON dep.partinvoiceid = pi.partinvoiceid
		INNER JOIN (
			SELECT pi.partinvoiceid
			FROM maedata d
			INNER JOIN papartinvoice pi ON d.rawdocumenttype = 1001
				AND pi.partinvoiceid = d.rawdocumentid
			INNER JOIN papartinvoicetotals pit ON pit.partinvoiceid = pi.partinvoiceid
			INNER JOIN soamt ON soamt.partinvoiceid = pi.partinvoiceid
				AND pi.specialordercollectamount = (soamt.amt + pit.specialordertax)
			) soa ON soa.partinvoiceid = pi.partinvoiceid
		INNER JOIN papartinvoice pin ON pi.partinvoiceid = pin.partinvoiceid
		INNER JOIN cosaletype st ON st.saletypeid = pin.handlingsaletypeid
		INNER JOIN soamt ON soamt.partinvoiceid = pin.partinvoiceid
		WHERE ba.rawdocumenttype = 1001
			AND ba.rawSTATUS = 2
			AND dep.applied <> ba.rawoobamt
			AND abs(pin.invoicehandlingamt + pin.specialorderhandling) != abs(ba.rawoobamt) -- didn't charge handling
		GROUP BY ba.businessactionid
		) data
	GROUP BY businessactionid
	),
oobdepositapplied -- optimized, and took out of nested query
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoicetotals pit ON ba.rawdocumentid = pit.partinvoiceid
	INNER JOIN papartinvoiceline pil ON ba.rawdocumentid = pil.partinvoiceid
	INNER JOIN paspecialorder so ON so.specialorderid IN (pil.specialorderid, pil.layawayid)
	WHERE ba.rawSTATUS = 2
		AND (
			pil.qtypickedup > 0
			OR pil.qtyspecialorder < 0
			)
		AND so.isconversion = false
		AND pil.dealadjustmentid IS NULL
		AND abs(ba.rawoobamt) > 500 -- BUG FIX, MAY CAUSE ISSUES
	GROUP BY ba.rawdocumentid,
		ba.businessactionid
	HAVING SUM(pil.depositapplied) <> MAX(pit.soldnowprepaidamount)
	),
oobdepositappliedpenny -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoicetotals pit ON ba.rawdocumentid = pit.partinvoiceid
	INNER JOIN papartinvoiceline pil ON ba.rawdocumentid = pil.partinvoiceid
	GROUP BY ba.businessactionid
	HAVING ABS(SUM(pil.depositapplied) - MAX(pit.soldnowprepaidamount)) BETWEEN 100
			AND 500
	),
oobnonpaypartinvoice -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoice pi ON ba.rawdocumentid = pi.partinvoiceid
	INNER JOIN cosaletype st ON pi.handlingsaletypeid = st.saletypeid
	WHERE ba.rawSTATUS = 2
		AND st.usagecode = 7
		AND pi.invoicehandlingamt + pi.specialorderhandling != 0
		AND pi.invoicehandlingamt + pi.specialorderhandling = ba.rawoobamt
	),
oobhandlingpartinvoice -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoice pi ON ba.rawdocumentid = pi.partinvoiceid
	INNER JOIN cosaletype st ON pi.handlingsaletypeid = st.saletypeid
	WHERE ba.rawSTATUS = 2
		AND st.usagecode != 7
		AND pi.invoicehandlingamt + pi.specialorderhandling != 0
		AND ABS(pi.invoicehandlingamt + pi.specialorderhandling) = ABS(ba.rawoobamt)
	),
taxoobpartinvoice -- https://lightspeeddms.atlassian.net/browse/EVO-17198 -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoicetaxitem piti ON ba.rawdocumenttype = 1001
		AND ba.rawstatus = 2
		AND ba.rawdocumentid = piti.partinvoiceid
	INNER JOIN papartinvoicetaxentity pite ON piti.partinvoicetaxitemid = pite.partinvoicetaxitemid
	WHERE (piti.taxamount - pite.taxamount) = ba.rawoobamt
	GROUP BY ba.businessactionid
	),
armopinternalinvoice
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoice pi ON pi.partinvoiceid = ba.rawdocumentid
	INNER JOIN paymentinfo pyi ON pyi.businessactionid = ba.businessactionid
	WHERE ba.rawSTATUS = 2
		AND ba.rawtxt ilike 'No A/R Customer for Method of Payment %'
		AND pi.invoicetype = 1
		AND pi.majorunitid != 0
		AND pyi.mopamount = 0
	GROUP BY ba.businessactionid
	),
oobmissingmopccmapping
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN paymentinfo cip ON cip.businessactionid = ba.businessactionid
	INNER JOIN cocreditcardtransaction ct ON ct.documentid = ba.rawdocumentid
	WHERE '' = ALL (cip.mopdescriptionsarr)
		AND cip.mopamount != 0
		AND ba.rawstatus = 2
	),
oobmissingmoppartinvoice -- optimized
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoice pi ON ba.rawdocumentid = pi.partinvoiceid
	INNER JOIN papartinvoicetotals pit ON pi.partinvoiceid = pit.partinvoiceid
	INNER JOIN paymentinfo pyi ON pyi.businessactionid = ba.businessactionid
	WHERE ba.rawSTATUS = 2
		AND pi.invoicetype NOT IN (2, 3)
		AND ABS(ba.rawoobamt) = ABS(pit.soldnowsubtotal) OR ABS(ba.rawoobamt) = ABS(pit.soldnowdiscount)
		AND pyi.mopamount = 0
	),
oobzerosummoppartinvoice -- optimized
AS (
	-- EVO-31037
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN papartinvoice pi ON ba.rawdocumenttype = 1001
		AND ba.rawSTATUS = 2
		AND ba.rawdocumentid = pi.partinvoiceid
	INNER JOIN papartinvoicetotals pit ON pi.partinvoiceid = pit.partinvoiceid
	INNER JOIN paymentinfo p ON ba.businessactionid = p.businessactionid
	WHERE pi.invoicetype NOT IN (2, 3)
		AND ABS(ba.rawoobamt) = pit.invoicesubtotal
		AND '' != ALL (p.mopdescriptionsarr)
		AND p.mopamount = 0
		AND p.mopcount > 1
	),
oobwrongmopamountrepairorder
AS (
	SELECT ba.businessactionid
	FROM cocommoninvoicepayment cip
	INNER JOIN cocommoninvoice ci ON ci.commoninvoiceid = cip.commoninvoiceid
	INNER JOIN serepairorder ro ON ro.repairorderid = ci.documentid
	INNER JOIN serototals rt ON rt.roid = ro.repairorderid
	INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
	WHERE ba.rawstatus = 2
		AND ro.storeid = ba.storeid
	GROUP BY roid,
		ba.businessactionid
	HAVING sum(cip.amount) != rt.rototalnw
	),
dealoobins -- NEEDS OPTIMIZATION
AS (
	SELECT ba.businessactionid
	FROM sadealfinalization df
	INNER JOIN sadeal d ON d.dealid = df.dealid
	INNER JOIN maedata ba ON ba.rawdocumentid = df.dealfinalizationid
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
	WHERE ba.rawSTATUS = 2
		AND (amts + ba.oobamt) / 2 = di.insprice
		AND ((amts + ba.oobamt) * - 1) / 2 = d.balancetofinance
	),
oobwrongamtsalesdeal
AS (
	SELECT b.businessactionid
	FROM sadeal A
	INNER JOIN sadealfinalization df ON df.dealid = a.dealid
	INNER JOIN maedata b ON b.rawdocumentid = df.dealfinalizationid
	INNER JOIN paymentinfo p ON p.businessactionid = b.businessactionid
	WHERE B.rawSTATUS = 2
		AND (
			'' != ALL (p.mopdescriptionsarr)
			OR mopdescriptionsstr IS NULL
			)
		AND p.mopamount != 0
	GROUP BY a.balancetofinance,
		p.businessactionid,
		b.businessactionid,
		p.mopcount,
		p.mopamount
	HAVING p.mopcount = 1
		AND p.mopamount != a.balancetofinance
	),
dupetaxrepairorder
AS (
	SELECT DISTINCT ba.businessactionid
	FROM serepairordertaxentity rote
	INNER JOIN serepairordertaxitem roti ON roti.repairordertaxitemid = rote.repairordertaxitemid
	INNER JOIN maedata ba ON ba.rawoobamt != 0
		AND ba.rawdocumentid = roti.repairorderid
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
	WHERE rote.storeid = ba.storeid
		AND dup.row > 1
	),
taxroundingrepairorder -- heavily modified 13501 NOT VERIFIED TO WORK yet 
AS (
	SELECT businessactionid
	FROM (
		SELECT ba.businessactionid
		FROM serepairordertaxentity e
		INNER JOIN serepairordertaxitem i ON e.repairordertaxitemid = i.repairordertaxitemid
		INNER JOIN serepairorder ro ON ro.repairorderid = i.repairorderid
		INNER JOIN maedata ba ON ba.rawdocumentid = ro.repairorderid
		WHERE ba.rawSTATUS = 2
		GROUP BY ba.businessactionid,
			i.repairordertaxitemid
		HAVING i.taxamount != ROUND(SUM(e.taxamount), - 2)
			AND SUM(e.taxamount) != SUM(ROUND(e.taxamount, - 2))
		) error
	GROUP BY businessactionid
	),
rentalmopdealdeposit
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN cocommoninvoice ci ON ba.rawSTATUS = 2 -- ma is in error status
		AND ba.rawdocumenttype = 3002 -- deal depoosit
		AND ci.invoicenumber::VARCHAR = ba.invoicenumber
	INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
	INNER JOIN comethodofpayment mop ON mop.arentryoption = 3
		AND mop.methodofpaymentid = cip.methodofpaymentid
	),
blankmopdealdeposit -- need to convert to '' != ALL (p.mopdescriptionsarr)
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN cocommoninvoice ci ON ba.rawSTATUS = 2 -- ma is in error status
		AND ba.rawdocumenttype = 3002 -- deal depoosit
		AND ci.invoicenumber::VARCHAR = ba.invoicenumber
	INNER JOIN cocommoninvoicepayment cip ON cip.commoninvoiceid = ci.commoninvoiceid
	INNER JOIN comethodofpayment mop ON (
			mop.description = ''
			OR mop.description = NULL
			)
		AND cip.amount != 0
		AND mop.methodofpaymentid = cip.methodofpaymentid
	),
invalidglrentalblankmop
AS (
	SELECT ba.businessactionid
	FROM mabusinessaction ba
	INNER JOIN paymentinfo pi ON ba.businessactionid = pi.businessactionid
	WHERE ba.STATUS = 2
		AND ba.documenttype = 4002
		AND (
			pi.mopcount > 1
			OR pi.mopamount < 0
			)
		AND '' = ANY (pi.mopdescriptionsarr)
	),
extralinevendor -- optimized 
AS (
	SELECT ba.businessactionid
	FROM maedata ba
	INNER JOIN sadealfinalization df ON ba.rawSTATUS = 4
		AND ba.rawdocumentid = df.dealfinalizationid
	INNER JOIN sadeal d ON df.dealid = d.dealid
	INNER JOIN sadealunit du ON d.dealid = du.dealid
	INNER JOIN sadealunitextraline l ON du.dealunitid = l.dealunitid
	LEFT JOIN apvendor v ON l.apvendorid = v.vendorid
	WHERE v.vendorid IS NULL
		AND l.apvendorid != 0
	GROUP BY ba.businessactionid
	)
SELECT ba.documentnumber AS document_number,
	ba.invoicenumber AS invoice_number,
	ba.doctype AS documenttype,
	ba.errorstatus AS STATUS,
	ba.docdate AS DATE,
	ba.storename || ', Id:' || ba.rawstoreid::VARCHAR AS storeandstoreid,
	ba.rawdocumentid AS documentid,
	CASE 
		WHEN ba.storeid = 0
			AND ba.rawdocumentid = 0
			AND ba.rawstatus = 2
			THEN 'EVO-20030 Document Missing from MAE List | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN schedacctnotvalidar.businessactionid IS NOT NULL
			THEN 'EVO-38097 Scheduled Not Valid for A/R Customerid XXXXX PSS Items | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN miscinvnonarmop.businessactionid IS NOT NULL
			THEN 'EVO-33866 Scheduled Not Valid for A/R Customerid XXXXX Misc Receipt | T2 '
		ELSE ''
		END || CASE 
		WHEN dealarglaccount.businessactionid IS NOT NULL
			THEN 'EVO-3087 Scheduled Account XXXX Not Valid for A/R Customerid XXXXX Sales Deal | T1 Front End Fix, See CR for info. May be EVO-30821 but not likely'
		ELSE ''
		END || CASE 
		WHEN earop.businessactionid IS NOT NULL
			THEN 'EVO-26911 Error Accessing RO Part Category | T2 '
		ELSE ''
		END || CASE 
		WHEN rentalmopdealdeposit.businessactionid IS NOT NULL
			THEN 'EVO-33052 Deal Deposit, No ReservationID For Account XXXX  | T2 '
		ELSE ''
		END || CASE 
		WHEN blankmopdealdeposit.businessactionid IS NOT NULL
			THEN 'EVO-29597 Deal Deposit, Invalid GL ID = 0, Blank MOP  | T2 '
		ELSE ''
		END || CASE 
		WHEN earol.businessactionid IS NOT NULL
			OR earol2.businessactionid IS NOT NULL
			THEN 'EVO-18036 Error Accessing RO Labor Category | T2 '
		ELSE ''
		END || CASE 
		WHEN erroraccmiscsaletype.businessactionid IS NOT NULL
			THEN 'EVO-39691 Error Accessing RO Misc Charge Saletype'
		ELSE ''
		END || CASE 
		WHEN eapicat.businessactionid IS NOT NULL -- Error Accessing on Part Invoice // Verified Diag To Work
			THEN 'EVO-13570 Error Accessing Part Invoice Category | T2 '
		ELSE ''
		END || CASE 
		WHEN earpcat.businessactionid IS NOT NULL -- Error Accessing On Part Receiving Document
			THEN 'EVO-31748 Error Accessing Receiving Document Part Category | T2 '
		ELSE ''
		END || CASE 
		WHEN partinvoicescheduledmu.businessactionid IS NOT NULL
			OR partinvoicescheduledmu1.businessactionid IS NOT NULL -- Error Accessing On Part Receiving Document
			THEN 'EVO-14901 Part Category Has MU Scheduled Inventory Account | T2 '
		ELSE ''
		END || CASE 
		WHEN partinvoicemubadsaletype.businessactionid IS NOT NULL -- EVO-14158
			THEN 'EVO-14158 Part Invoice Non Sales Saletype on Internal Invoice | T2 '
		ELSE ''
		END || CASE 
		WHEN subletcloseoutscheduledmu.businessactionid IS NOT NULL
			THEN 'EVO-13300 Sublet Category Has MU Scheduled Inventory Account | T2 '
		ELSE ''
		END || CASE 
		WHEN analysispending.businessactionid IS NOT NULL -- Analysis Pending On Part Receiving Document
			THEN 'EVO-29301 Analysis Pending on Part Receiving Document | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN dealunitbadsaletype.businessactionid IS NOT NULL -- Analysis Pending On Part Receiving Document
			THEN 'EVO-26651 Error Accessing Category ID, Bad Saletype on deal | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN invalidglnonpayro.businessactionid IS NOT NULL -- Invalid GL For Non-Pay Job on Repair Order
			THEN 'EVO-34114 Invalid GL Account ID = 0 Non-Pay Repair Order | T2 '
		ELSE ''
		END || CASE 
		WHEN invalidglblankmopinvoice.businessactionid IS NOT NULL
			OR invalidglblankmopdeal.businessactionid IS NOT NULL -- Invalid GL for MOP on Sales Deal or Part Invoice // UNABLE TO DIFFERENTIATE BETWEEN DEPOSIT APPLIED AND NO PAYMENT
			THEN 'EVO-35010 Invalid GL Account ID = 0 blank MOP sales deal or part invoice | T2 '
		ELSE ''
		END || CASE 
		WHEN invalidglclaimsubmission.businessactionid IS NOT NULL
			THEN 'EVO-29577 Invalig GL Account ID = 0 Warranty Claim Submission | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN taxidrental.businessactionid IS NOT NULL -- Rental Reservation with bad taxid
			THEN 'EVO-12777 Could not Locate Tax Entity Reservation | T2 '
		ELSE ''
		END || CASE 
		WHEN longvaltax.businessactionid IS NOT NULL
			THEN 'EVO-37225 Invalid Monetary Fraction XXX Document, Long Value Tax | T2 '
		ELSE ''
		END || CASE 
		WHEN taxiddeal1.businessactionid IS NOT NULL -- Deal with bad taxid linked to diff store
			THEN 'EVO-9836 Error Getting Unit Tax Information | T2 '
		ELSE ''
		END || CASE 
		WHEN taxiddeal2.businessactionid IS NOT NULL -- Deal with bad taxid linked to diff store
			THEN 'EVO-26472 Error Updating Accounting | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN dealtaxroundpenny.businessactionid IS NOT NULL -- deal out of balance by a penny due to tax rounding
			THEN 'EVO-17784 Deal Not Rounded by Penny | T2, SQL in CR'
		ELSE ''
		END || CASE 
		WHEN taxidpartinvoice1.businessactionid IS NOT NULL -- part invoice tax entity with bad taxentityid https://lightspeeddms.atlassian.net/browse/EVO-35995
			THEN 'EVO-35995 Could Not Locate Tax Entity XXX | T2 '
		ELSE ''
		END || CASE 
		WHEN tradedealid.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-22520 Trade Deal ID Issue Diag Not Verified | N/A'
		ELSE ''
		END || CASE 
		WHEN dealunitid1.businessactionid IS NOT NULL -- MU with bad dealunitid // NOT TESTED, PLEASE CORRECT IF NOT WORKING
			THEN 'EVO-21635 Error Accessing, RO Unit with Bad Deal ID | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN groupfordealunitid.businessactionid IS NOT NULL -- MU with bad dealunitid // NOT TESTED, PLEASE CORRECT IF NOT WORKING
			THEN 'EVO-16159 Cant find group for dealunitid | T2 '
		ELSE ''
		END || CASE 
		WHEN oobdupepartinvoice.businessactionid IS NOT NULL -- Tested and confirmed Duplicate Part invoice / SO
			THEN 'EVO-36594 Duplicate Part Invoice / SO | T2 '
		ELSE ''
		END || CASE 
		WHEN oobmissingdiscountpartinvoice.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-20828 Part Invoice OOB Missing Discounts on Lines | T2 '
		ELSE ''
		END || CASE 
		WHEN oobdepositapplied.businessactionid IS NOT NULL -- potentially works, got flagged by 20828 diag but preapproved made that part of error go away
			THEN 'EVO-17384 Part Invoice OOB Deposit Applied | T1'
		ELSE ''
		END || CASE 
		WHEN oobdepositappliedpenny.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-20339 Part Invoice OOB Deposit Applied By A Penny | T1'
		ELSE ''
		END || CASE 
		WHEN negativedealtax.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-18151 Deal OOB By Negative Tax Lines | T1'
		ELSE ''
		END || CASE 
		WHEN negativedealtaxnew.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-42036 Deal OOB By Negative Tax Lines | T2 '
		ELSE ''
		END || CASE 
		WHEN oobnonpaypartinvoice.businessactionid IS NOT NULL -- Semi-verified
			THEN 'EVO-39247 Part Invoice OOB Non-Pay Handling Amt | T2 '
		ELSE ''
		END || CASE 
		WHEN invalidglrentalblankmop.businessactionid IS NOT NULL -- Semi-verified
			THEN 'EVO-35588 Invalid GL Blank Rental MOP | T2 '
		ELSE ''
		END || CASE 
		WHEN oobhandlingpartinvoice.businessactionid IS NOT NULL -- Semi-verified
			THEN 'EVO-37782 Part Invoice OOB Handling Amt | T2 '
		ELSE ''
		END || CASE 
		WHEN oobzerosummoppartinvoice.businessactionid IS NOT NULL
			THEN 'EVO-31037 Part Invoice Payment Refunded invoice amount | T2 '
		ELSE ''
		END || CASE 
		WHEN armopinternalinvoice.businessactionid IS NOT NULL
			THEN 'EVO-31066 Internal Invoice Using AR MOP | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN taxoobpartinvoice.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-17198 Part Invoice OOB Tax Not Rounded Properly | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN oobmissingmoppartinvoice.businessactionid IS NOT NULL
			THEN 'EVO-40858 Invoice OOB paid with Blank Method of Payment 0$ | T2 '
		ELSE ''
		END || CASE 
		WHEN oobmissingmopccmapping.businessactionid IS NOT NULL
			THEN 'EVO-38574 Invalid GL Account ID = 0, CC Mop Bad System Preferences Mapping | T2 '
		ELSE ''
		END || CASE 
		WHEN oobwrongmopamountrepairorder.businessactionid IS NOT NULL -- Invalid GL for MOP on Sales Deal or Part Invoice
			THEN 'EVO-30796 Repair Order OOB Method of Payment Amount Incorrect | T2 '
		ELSE ''
		END || CASE 
		WHEN dealoobins.businessactionid IS NOT NULL -- VERIFIED
			THEN 'EVO-24051 Deal OOB insurance Forces Negative Balance to Finance | T2 '
		ELSE ''
		END || CASE 
		WHEN oobwrongamtsalesdeal.businessactionid IS NOT NULL -- VERIFIED
			THEN 'EVO-31125 Sales Deal OOB Method of Payment != Balance to Finance | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN mutransferstoreid.businessactionid IS NOT NULL -- VERIFIED
			THEN 'EVO-31390 Major Unit Transfer with Bad MU Sales Category | T2 '
		ELSE ''
		END || CASE 
		WHEN taxroundingrepairorder.businessactionid IS NOT NULL -- NOT VERIFIED WAITING TO TEST
			THEN 'EVO-13501 Tax Entity not rounded Repair Order | T1 Preapproved '
		ELSE ''
		END || CASE 
		WHEN extralinevendor.businessactionid IS NOT NULL
			THEN 'EVO-40791 Pending deal, cannot get vendorName, vendorid null | T1, See CR For Details'
		ELSE ''
		END || CASE 
		WHEN dupetaxrepairorder.businessactionid IS NOT NULL
			THEN 'EVO-34321 Duplicate Taxes on Repair Order | T2 '
		ELSE ''
		END AS issue_description_and_cr,
	CASE 
		WHEN ba.oobamt != 0
			THEN ba.oob
		ELSE 'N/A'
		END AS balancestate,
	ba.txt AS errormessage, pi.mopdescriptionsstr
FROM maedata ba
LEFT JOIN paymentinfo pi on pi.businessactionid = ba.businessactionid
LEFT JOIN erroraccropart earop ON earop.businessactionid = ba.businessactionid -- EVO-26911 RO Part with Bad Categoryid
LEFT JOIN erroraccrolabor earol ON earol.businessactionid = ba.businessactionid -- EVO-18036 RO Labor with Bad Categoryid
LEFT JOIN erroraccrolabor2 earol2 ON earol2.businessactionid = ba.businessactionid -- EVO-18036 RO Labor with Bad Categoryid
LEFT JOIN erroraccpicat eapicat ON eapicat.businessactionid = ba.businessactionid -- EVO-13570 Part Invoice Line with Bad Categoryid
LEFT JOIN erroraccreceivepart earpcat ON earpcat.businessactionid = ba.businessactionid -- EVO-31748 Part Receiving Doc with Bad Categoryid
LEFT JOIN erroraccmiscsaletype ON erroraccmiscsaletype.businessactionid = ba.businessactionid -- EVO-39691 RO with bad misc item categoryid
LEFT JOIN partinvoicescheduledmu ON partinvoicescheduledmu.businessactionid = ba.businessactionid
LEFT JOIN partinvoicescheduledmu1 ON partinvoicescheduledmu1.businessactionid = ba.businessactionid -- EVO-14901 Part invoice version
LEFT JOIN subletcloseoutscheduledmu ON subletcloseoutscheduledmu.businessactionid = ba.businessactionid
LEFT JOIN analysispending ON analysispending.businessactionid = ba.businessactionid
LEFT JOIN invalidglnonpayro ON invalidglnonpayro.businessactionid = ba.businessactionid
LEFT JOIN invalidglblankmopinvoice ON invalidglblankmopinvoice.businessactionid = ba.businessactionid -- EVO-35010
LEFT JOIN invalidglblankmopdeal ON invalidglblankmopdeal.businessactionid = ba.businessactionid -- EVO-35010
LEFT JOIN invalidglclaimsubmission ON invalidglclaimsubmission.businessactionid = ba.businessactionid -- EVO-29577
LEFT JOIN schedacctnotvalidar ON schedacctnotvalidar.businessactionid = ba.businessactionid -- EVO-38907 AR Sched Acct not valid for MOP
LEFT JOIN miscinvnonarmop ON miscinvnonarmop.businessactionid = ba.businessactionid -- EVO-33866 AR Sched Invalid for Misc Receipt
LEFT JOIN dealarglaccount ON dealarglaccount.businessactionid = ba.businessactionid -- EVO-3087
LEFT JOIN taxidrental ON taxidrental.businessactionid = ba.businessactionid -- EVO-12777 Rental Reservation with bad rental posting taxid
LEFT JOIN longvaltax ON longvaltax.businessactionid = ba.businessactionid -- EVO-37225 long val tax not rounded
LEFT JOIN taxiddeal1 ON taxiddeal1.businessactionid = ba.businessactionid -- EVO-9836 Deal Unit tax with invalid taxentityid
LEFT JOIN taxiddeal2 ON taxiddeal2.businessactionid = ba.businessactionid -- EVO-26472 Deal Unit Tax with taxentityid from other store
LEFT JOIN dealtaxroundpenny ON dealtaxroundpenny.businessactionid = ba.businessactionid -- EVO-17784
LEFT JOIN taxidpartinvoice1 ON taxidpartinvoice1.businessactionid = ba.businessactionid -- EVO-35995 
LEFT JOIN negativedealtax ON negativedealtax.businessactionid = ba.businessactionid -- EVO-18151 
LEFT JOIN negativedealtaxnew ON negativedealtaxnew.businessactionid = ba.businessactionid -- EVO-42036 
LEFT JOIN tradedealid ON tradedealid.businessactionid = ba.businessactionid -- EVO-22520 Deal Trade MAE with invalid tradedealid
LEFT JOIN dealunitid1 ON dealunitid1.businessactionid = ba.businessactionid -- EVO-21635 Deal Unit ID linking to invalid dealunit
LEFT JOIN mutransferstoreid ON mutransferstoreid.businessactionid = ba.businessactionid -- EVO-21635 Deal Unit ID linking to invalid dealunit
LEFT JOIN dealoobins ON dealoobins.businessactionid = ba.businessactionid -- EVO-24051
LEFT JOIN oobzerosummoppartinvoice ON oobzerosummoppartinvoice.businessactionid = ba.businessactionid
LEFT JOIN oobdupepartinvoice ON oobdupepartinvoice.businessactionid = ba.businessactionid
LEFT JOIN oobmissingdiscountpartinvoice ON oobmissingdiscountpartinvoice.businessactionid = ba.businessactionid
	AND oobzerosummoppartinvoice.businessactionid IS NULL -- EVO-20828
LEFT JOIN oobnonpaypartinvoice ON oobnonpaypartinvoice.businessactionid = ba.businessactionid -- EVO-39247
LEFT JOIN groupfordealunitid ON groupfordealunitid.businessactionid = ba.businessactionid -- EVO-16159
LEFT JOIN oobdepositapplied ON oobdepositapplied.businessactionid = ba.businessactionid -- EVO-17384
LEFT JOIN oobdepositappliedpenny ON oobdepositappliedpenny.businessactionid = ba.businessactionid -- EVO-20339
LEFT JOIN oobhandlingpartinvoice ON oobhandlingpartinvoice.businessactionid = ba.businessactionid -- EVO-37782
LEFT JOIN taxoobpartinvoice ON taxoobpartinvoice.businessactionid = ba.businessactionid -- EVO-17198 taxes oob compared to tax entity amounts
LEFT JOIN oobmissingmopccmapping ON oobmissingmopccmapping.businessactionid = ba.businessactionid -- EVO-38574
LEFT JOIN oobmissingmoppartinvoice ON oobmissingmoppartinvoice.businessactionid = ba.businessactionid
LEFT JOIN armopinternalinvoice ON armopinternalinvoice.businessactionid = ba.businessactionid -- EVO-31066
LEFT JOIN oobwrongmopamountrepairorder ON oobwrongmopamountrepairorder.businessactionid = ba.businessactionid -- EVO-30796 Mop Amount less than Amount to Collect on RO
LEFT JOIN oobwrongamtsalesdeal ON oobwrongamtsalesdeal.businessactionid = ba.businessactionid -- EVO-31125
LEFT JOIN taxroundingrepairorder ON taxroundingrepairorder.businessactionid = ba.businessactionid
	AND oobmissingmopccmapping.businessactionid IS NULL
LEFT JOIN rentalmopdealdeposit ON rentalmopdealdeposit.businessactionid = ba.businessactionid -- EVO-41900
LEFT JOIN blankmopdealdeposit ON blankmopdealdeposit.businessactionid = ba.businessactionid -- EVO-29597
LEFT JOIN invalidglrentalblankmop ON invalidglrentalblankmop.businessactionid = ba.businessactionid -- EVO-35588
LEFT JOIN dealunitbadsaletype ON dealunitbadsaletype.businessactionid = ba.businessactionid -- EVO-26651
LEFT JOIN extralinevendor ON extralinevendor.businessactionid = ba.businessactionid -- EVO-40791
LEFT JOIN partinvoicemubadsaletype ON partinvoicemubadsaletype.businessactionid = ba.businessactionid -- EVO-14158
LEFT JOIN dupetaxrepairorder ON dupetaxrepairorder.businessactionid = ba.businessactionid -- EVO-34321
WHERE ba.rawSTATUS IN (2, 4)
ORDER BY ba.storename ASC,
	ba.rawdocumentdate DESC;
