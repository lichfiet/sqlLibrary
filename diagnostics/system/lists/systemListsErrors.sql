WITH storeinfo
AS (
	SELECT co.value AS CMF, -- cmf number 
		s.storename AS StoreName, -- name of store in store select
		s.storeid AS StoreID,
		co2.value AS LocationName, -- shows up in top left of Lightspeed
		s.storecode AS StoreCode
	FROM copreference co
	INNER JOIN costore s ON s.storeid = co.storeid
	INNER JOIN costoremap sm ON sm.childstoreid = s.storeid
	LEFT JOIN (
		SELECT string_agg(s.storename, ', ') OVER (PARTITION BY parentstoreid) AS stores,
			array_agg(s.storeid) OVER (PARTITION BY parentstoreid) AS storeids,
			childstoreid
		FROM costoremap sm
		INNER JOIN costore s ON s.storeid = sm.childstoreid
		) otherstores ON otherstores.childstoreid = s.storeid
	INNER JOIN copreference co2 ON co2.storeidluid = co.storeidluid
	WHERE co.id = 'shop-DealerID'
		AND co2.id = 'shop-LocationName'
	ORDER BY co2.value ASC
	),
evo27246
AS (
	SELECT cst.storeid
	FROM cocategorysaletype cst
	LEFT JOIN cosaletype st ON st.saletypeid = cst.saletypeid
	WHERE st.saletypeid IS NULL
	GROUP BY cst.storeid
	)
SELECT CASE 
		WHEN evo27246.storeid IS NULL
			THEN ''
		ELSE 'EVO-27246 Error Opening Sales Category'
		END AS crs,
	si.*
FROM storeinfo si
LEFT JOIN evo27246 ON si.storeid = evo27246.storeid
