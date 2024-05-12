-- INSTRUCTIONS
-- 1. Run the duplicate diagnostic so you do not make any duplicate categories that exist in the new store,
--    but might not have matching names. you'll need to change the copy from and to storeids. if the category exists in the store you are copying to,
--    but the SQL still tells you 'category xx does not exists in the new store' and you have
--    already created it in that new location, make sure the names match so you do not create 
--    any duplicate tax categories that you can't delete.
--
-- 2. change lines 7, 9, and 11 on the update to match the store you are copying from, the store you
--    are copying to, and the username you want associated with creating the tax categories, then run
--    both insert SQLs, and the update at the end all at the same time.
WITH settings
AS (
	SELECT 
    -- settings
		--
		99 AS copy_from_store, -- originating store
		--
		99 AS copy_to_store -- new store
		--
	),
removeduplicate
AS (
	SELECT ct.taxcategorydescription,
		ct.taxcategoryid
	FROM cotaxcategory ct
	INNER JOIN settings s ON s.copy_to_store = ct.storeid
	INNER JOIN cotax t ON t.taxcategoryid = ct.taxcategoryid
	GROUP BY ct.taxcategoryid,
		ct.taxcategorydescription
	)
SELECT 'Tax Category: ( ' || ct.taxcategorydescription || ' ) is missing from the new store, if it does exist, please make sure the names match in the new store' AS description
FROM cotaxcategory ct
INNER JOIN costore currentstore ON currentstore.storeid = ct.storeid
INNER JOIN costore newstore ON newstore.storeid != currentstore.storeid
INNER JOIN settings s ON s.copy_from_store = currentstore.storeid
	AND newstore.storeid = copy_to_store
LEFT JOIN removeduplicate rd ON trim(lower(rd.taxcategorydescription)) = trim(lower(ct.taxcategorydescription))
WHERE rd.taxcategoryid IS NULL;
--
-- UPDATES
INSERT INTO cotaxcategory
SELECT *
FROM (
	WITH settings AS (
			SELECT --
				--
				99 AS copy_from_store, -- originating store
				--
				99 AS copy_to_store, -- new store
				--
				'username' AS username_of_category_maker -- username of the userid attached to the new categories
				--
			),
		removeduplicate AS (
			SELECT ct.taxcategorydescription,
				ct.taxcategoryid
			FROM cotaxcategory ct
			INNER JOIN settings s ON s.copy_to_store = ct.storeid
			INNER JOIN cotax t ON t.taxcategoryid = ct.taxcategoryid
			GROUP BY ct.taxcategoryid,
				ct.taxcategorydescription
			)
	SELECT generate_luid() AS taxcategoryid,
		ct.taxcategorydescription || ' ' || ct.taxcategoryid::TEXT AS descriptionplusoldid,
		0 AS partsglacct,
		0 AS serviceglacct,
		0 AS salesglacct,
		taxabletype,
		roundinglevel,
		calculationlevel,
		p.userid, -- userid of person making categories
		NOW() AS dtstamp,
		0 AS rentalglacct,
		newstore.storeid AS storeid,
		roundingmethod,
		NULL::integer AS preluidtaxcategoryid,
		newstore.storeidluid AS storeidluid
	FROM cotaxcategory ct
	INNER JOIN costore currentstore ON currentstore.storeid = ct.storeid
	INNER JOIN costore newstore ON newstore.storeid != currentstore.storeid
	INNER JOIN settings s ON s.copy_from_store = currentstore.storeid
		AND newstore.storeid = copy_to_store
	INNER JOIN coprincipal p ON p.username = s.username_of_category_maker
	LEFT JOIN removeduplicate rd ON trim(lower(rd.taxcategorydescription)) = trim(lower(ct.taxcategorydescription))
	WHERE rd.taxcategoryid IS NULL
	) taxinfo;
	
INSERT INTO cotax
SELECT *
FROM (
	SELECT generate_luid() AS taxid,
		t.rate AS rate,
		t.minimum AS minimum,
		t.maximum AS maximum,
		t.threshold AS threshold,
		t.sequence AS sequence,
		t.description AS description,
		insertedtax.taxcategoryid,
		0 AS partsglaccount,
		0 AS serviceglaccount,
		0 AS salesglaccount,
		0 AS rentalglaccount,
		insertedtax.storeid AS storeid,
		hasminimum AS hasminimum,
		hasmaximum AS hasmaximum,
		hasthreshold AS hasthreshold,
		isthresholdtaxable AS isthresholdtaxable,
		istaxable AS istaxable,
		NULL::INTEGER AS preluidtaxid,
		insertedtax.storeidluid AS storeidluid
	FROM cotax t
	INNER JOIN cotaxcategory ct ON ct.taxcategoryid = t.taxcategoryid
	INNER JOIN cotaxcategory insertedtax ON ct.taxcategoryid::VARCHAR = right(insertedtax.taxcategorydescription, length(ct.taxcategoryid::VARCHAR))
	) taxlineinfo;
	
UPDATE cotaxcategory ct
SET taxcategorydescription = bob.corrected_description
FROM (
	SELECT ct.taxcategorydescription AS corrected_description,
		insertedtax.taxcategoryid AS id
	FROM cotaxcategory ct
	INNER JOIN cotaxcategory insertedtax ON ct.taxcategoryid::VARCHAR = right(insertedtax.taxcategorydescription, length(ct.taxcategoryid::VARCHAR))
	) bob
WHERE bob.id = ct.taxcategoryid;


