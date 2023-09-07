-- Unhides your admin login so you can enable them to be a cashier
--
-- SQL Description: updates storeid and hidden status in coprincipal
-- How to Use: replace username on line 19 with your username, keep surround in % symbols
-- Jira Key/CR Number: N/A
-- SQL Statement:

UPDATE coprincipal c
SET ishidden = false,
	storeid = bob.stid,
	storeidluid = bob.stidluid
FROM (
	SELECT sm.childstoreid AS stid,
		sm.childstoreidluid AS stidluid
	FROM costore s
	INNER JOIN costoremap sm ON sm.childstoreid = s.storeid
	WHERE s.ismainstore = true
	) bob
WHERE username ilike '%lichfiet%';
