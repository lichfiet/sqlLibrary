-- finished barcode update
WITH barcodeupdateoffset
AS (
	SELECT CASE 
			WHEN value = '0'
				OR coa.acctdeptid IS NULL
				THEN 0
			ELSE 1
			END AS mapstate,
		storeid
	FROM copreference
	LEFT JOIN glchartofaccounts coa ON coa.acctdeptid::VARCHAR = value
	WHERE id = 'shop-InventoryPartUpdateOffsettingGLAccount'
		AND value = '0'
	),
warrcompanymapping
AS (
SELECT * FROM cowarrantycompany
)
SELECT bai.description,
	CASE 
		WHEN documentitemtype != 10060002
			THEN ''
		WHEN barcodeupdateoffset.mapstate = 1
			AND documentitemtype != 10060002
			THEN 'Mapped'
		WHEN barcodeupdateoffset.mapstate = 0
			AND documentitemtype != 10060002
			THEN '(System > Preferences > Parts Folder > Inventory Updating > Offset GL Account)'
		END AS barcodeupdate,
	*
FROM mabusinessactionitem bai
INNER JOIN mabusinessaction ba ON ba.businessactionid = bai.businessactionid
INNER JOIN barcodeupdateoffset ON barcodeupdateoffset.storeid = bai.storeid
WHERE ba.STATUS = 2;



-- for warranty
SELECT CASE 
		WHEN warrupdateAP.vendorid IS NOT NULL
			AND warrantyupdatetype = 1
			THEN 0
		WHEN warrantyupdatetype = 1
			AND warrupdateAP.vendorid IS NULL
			THEN 1
		WHEN warrupdategl.acctdeptid IS NOT NULL
			AND warrantyupdatetype = 2
			THEN 0
		WHEN warrantyupdatetype = 2
			AND warrupdategl.acctdeptid IS NULL
			THEN 1
		WHEN warrupdateAR.customerid IS NOT NULL
			AND warrantyupdatetype = 3
			THEN 0
		WHEN warrantyupdatetype = 3
			AND warrupdateAR.customerid IS NULL
			THEN 1
		END AS updatetypemapping,
	*
FROM cowarrantycompany wc
INNER JOIN costoremap sm ON sm.childstoreid = wc.storeid
LEFT JOIN apvendor warrupdateAP ON warrupdateAP.vendorid = wc.apvendor
	AND warrupdateAP.accountingid = sm.parentstoreid
LEFT JOIN glchartofaccounts warrupdateGL ON warrupdategl.acctdeptid = wc.warrantyupdateacct
	AND warrupdateGL.accountingid = sm.parentstoreid
LEFT JOIN cocustomer warrupdateAR ON warrupdatear.customerid = wc.arcustomer
	AND warrupdateAR.storeid = wc.storeid;

-- to find documentitemtypes for warranty
SELECT documentitemtype,
	MAX(description),
	MAX(businessactionitemid)
FROM mabusinessactionitem
GROUP BY documentitemtype
having MAX(description) ilike '%warranty%'
ORDER BY documentitemtype;

