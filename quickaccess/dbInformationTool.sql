-- Payroll Plus Information Select
--
-- SQL Description: Find storeid / CMF / storename / Payroll Plus ID / Payroll Integration Type
-- How to Use: Copy the SQL statement, paste it in phoenix, and click run, no modification is neccesary.
-- Jira Key/CR Number: N/A
-- SQL Statement:


SELECT co.storeid AS StoreID,
	co2.value AS CMF,
	co3.value AS LocationName,
	s.storecode AS StoreCode,
	s.storename AS StoreName,
	co.value AS PayrollType,
	co4.value AS PayrollPlus_ClientID
FROM copreference co
INNER JOIN costore s on s.storeid = co.storeid
INNER JOIN copreference co2 ON co2.storeidluid = co.storeidluid
INNER JOIN copreference co3 ON co3.storeidluid = co.storeidluid
INNER JOIN copreference co4 ON co4.storeidluid = co.storeidluid
WHERE co.id ilike '%shop-payroll-type%'
	AND co2.id = 'shop-DealerID'
	AND co3.id = 'shop-LocationName'
	AND co4.id = 'shop-payrollplus-CompanyID'
ORDER BY co.storeid ASC;
