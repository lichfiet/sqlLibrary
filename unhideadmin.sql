-- Unhides your admin login so you can enable them to be a cashier
--
-- SQL Description: updates storeid and hidden status in coprincipal
-- How to Use: replace username on line 19 with your username, keep surround in % symbols, then make sure you are logged in to the DB before you run the SQL
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

INSERT INTO coprincipaltype
SELECT p.userid,
	p.username,
	bob.typename,
	generate_luid()
FROM (
	SELECT row_Number() OVER (PARTITION BY typename) AS rownum,
		typename
	FROM coprincipaltype
	WHERE typename NOT ilike '%lead%'
	ORDER BY typename
	) bob
JOIN coprincipal p ON p.username ilike '%lichfiet%'
LEFT JOIN coprincipaltype pt ON pt.typename = bob.typename
	AND pt.userid = p.userid;
	
INSERT INTO coprincipalstore
SELECT p.username,
	sm.childstoreid,
	p.userid,
	p.storeid,
	sm.childstoreidluid
FROM costoremap sm
INNER JOIN costore s ON s.storeid = sm.childstoreid
JOIN coprincipal p ON p.username ilike '%lichfiet%'
WHERE s.istraining = false;



