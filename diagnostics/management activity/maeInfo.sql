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
		left(string_agg(errortext, ''), 70) || '...' AS txt,
		ba.STATUS AS rawstatus,
		ba.businessactionid AS rawbusinessactionid,
		ba.storeid AS rawstoreid,
		ba.documentid AS rawdocumentid,
		ba.documentdate AS rawdocumentdate
	FROM mabusinessaction ba
	LEFT JOIN mabusinessactionitem bai ON bai.businessactionid = ba.businessactionid
	LEFT JOIN mabusinessactionerror bae ON bae.businessactionid = ba.businessactionid
	WHERE ba.STATUS IN (2, 4)
	GROUP BY ba.businessactionid,
		documentnumber,
		STATUS,
		documenttype
	)
SELECT maedata.documentnumber AS docnumber,
	maedata.doctype AS documenttype,
	maedata.errorstatus AS STATUS,
	maedata.docdate AS DATE,
	s.storename || ', Id:' || s.storeid::VARCHAR AS storeandstoreid,
	ba.rawdocumentid,
	CASE 
		WHEN maedata.oobamt != 0
			THEN maedata.oob
		ELSE 'N/A'
		END AS balancestate,
	maedata.txt AS errormessage
FROM maedata ba
LEFT JOIN maedata ON maedata.businessactionid = ba.businessactionid
LEFT JOIN costore s ON s.storeid = ba.rawstoreid
WHERE ba.rawSTATUS IN (2, 4)
ORDER BY s.storename ASC,
	ba.rawdocumentdate DESC
