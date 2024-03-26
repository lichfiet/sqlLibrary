WITH storeinfo
AS (
	SELECT *
	FROM costore
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
