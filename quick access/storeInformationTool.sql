-- GENERAL STORE AND ACCOUNTING INFO 
SELECT co.value AS CMF, -- cmf number 
	s.storename AS StoreName, -- name of store in store select
	sm.parentstoreid AS AccountingID,
	s.storeid AS StoreID,
	co2.value AS LocationName, -- shows up in top left of Lightspeed
	s.storecode AS StoreCode,
	CASE 
		WHEN array_length(otherstores.storeids, 1) = 1
			THEN 'Single Store Accounting'
		ELSE 'Shared Accounting'
		END AS sharedaccounting
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
ORDER BY co2.value ASC;

-- ACCOUNTING INFO 
SELECT s.storename AS AccountingStoreName, -- name of store in store select
	s.storeid AS AccountingID,
	s.storecode AS StoreCode,
	CASE 
		WHEN array_length(otherstores.storeids, 1) = 1
			THEN 'Single Store Accounting: [' || otherstores.stores || ']'
		ELSE 'Shared Accounting, Stores: [' || otherstores.stores || ']'
		END AS sharedaccountingstores
FROM costore s
INNER JOIN (
	SELECT string_agg(s.storename, ', ') AS stores,
		array_agg(s.storeid) AS storeids,
		parentstoreid
	FROM costoremap sm
	INNER JOIN costore s ON s.storeid = sm.childstoreid
	GROUP BY parentstoreid
	) otherstores ON otherstores.parentstoreid = s.storeid
ORDER BY s.storeid ASC;

/* PAYROLL PLUS INFOMATION  */
SELECT co2.value AS CMF, -- cmf number
	s.storename AS StoreName, -- name of store in store select
	co3.value AS LocationName, -- shows up in top left of Lightspeed
	co.value AS PayrollType,
	co4.value AS PayrollPlus_ClientID,
	co5.value AS prpUserLogin
FROM copreference co
INNER JOIN costore s ON s.storeid = co.storeid
INNER JOIN copreference co2 ON co2.storeidluid = co.storeidluid
INNER JOIN copreference co3 ON co3.storeidluid = co.storeidluid
INNER JOIN copreference co4 ON co4.storeidluid = co.storeidluid
INNER JOIN copreference co5 ON co5.storeidluid = co.storeidluid
WHERE co.id = 'shop-payroll-type'
	AND co2.id = 'shop-DealerID'
	AND co3.id = 'shop-LocationName'
	AND co4.id = 'shop-payrollplus-CompanyID'
	AND co5.id = 'shop-payrollplus-UserID'
ORDER BY CASE 
		WHEN co.value = 'None'
			THEN 0
		ELSE 1
		END DESC,
	co3.value ASC;
