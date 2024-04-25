WITH search
AS (
    --
	/* Replace CHANGE ME with the deal number you want to run the diagnostic for */
	--
	SELECT 'CHANGE ME' AS dealnumber
		--
		--
	),
dealinfo
AS (
	SELECT co.value AS CMF, -- cmf number 
		s.storename AS StoreName, -- name of store in store select
		s.storeid AS StoreID,
		co2.value AS LocationName, -- shows up in top left of Lightspeed
		s.storecode AS StoreCode,
		d.dealnumber AS Deal_Number,
		d.dealid AS dealid
	FROM sadeal d
	INNER JOIN copreference co ON co.storeid = d.storeid
	INNER JOIN costore s ON s.storeid = co.storeid
	INNER JOIN costoremap sm ON sm.childstoreid = s.storeid
	INNER JOIN copreference co2 ON co2.storeidluid = co.storeidluid
	INNER JOIN search ON search.dealnumber = d.dealnumber::varchar
	WHERE co.id = 'shop-DealerID'
		AND co2.id = 'shop-LocationName'
	ORDER BY co2.value ASC
	),
evo26439
AS (
	SELECT du.dealid,
		'EVO-26439 - Negative parts request unable to be fulfilled | T1 Preapproved' AS description
	FROM samajorunitpart mup
	INNER JOIN samajorunit mu ON mu.STATE = 1
		AND soldqty + requestedqty <> 0
		AND mu.majorunitid = mup.majorunitid
	INNER JOIN samajorunitoption muo ON muo.majorunitoptionid = mup.majorunitoptionid
	INNER JOIN sadealunit du ON du.majorunitid = du.dealunitid
	WHERE muo.isreversed = 1
		AND mup.dtstamp > '2019-05-01'
	GROUP BY du.dealid
	)
SELECT 'CMF#: ' || di.cmf AS cmf_number,
	'Location: ' || di.storename AS location_name,
	'Deal #: (' || di.deal_number || ')',
	coalesce(evo26439.description, 'No CRs Identified On Deal') AS problem_description_and_cr,
	di.storeid
FROM dealinfo di
LEFT JOIN evo26439 ON evo26439.dealid = di.dealid;
