-- EVO-20828 List of Updates that may or may not work
--
-- SQL Description: Diagnostic to see if this is the issue, if it returns no results the issue is different
-- How to Use: Replace the 9999999999 below with a valid user id from coprincipal. If the fourth column says (Invlalid User ID) the userid is not valid
-- Jira Key/CR Number: EVO-31806 | https://lightspeeddms.atlassian.net/browse/EVO-31806
-- SQL Statement:

--
-- Note: You can ignore most of the comments, except for the ones that say (REPLACE ME)
-- which highlight the number that needs to be replaced in order for the update sql to work
--
SELECT tc.timecardid AS timecardid,
	CASE -- case when to let you know if the userid is valid
		WHEN newp.username IS NOT NULL
			THEN 'Valid User ID'
		ELSE 'Invalid User ID'
		END AS newusername,
	CASE -- case when to let you know if the userid is valid
		WHEN newp.username IS NOT NULL
			THEN newp.username
		ELSE '<-----'
		END AS newuservalidity,
	tc.principalid AS baduserid, -- current userid
	bob.newuserid AS newuserid -- newuserid
FROM cotimecard tc
LEFT JOIN coprincipal p ON p.userid = tc.principalid -- join current user assigned to time card with coprincipal
LEFT JOIN (
	SELECT (/* REPLACE ME --> */ 9999999999 /* <-- REPLACE ME */) AS newuserid
	) bob ON bob.newuserid = bob.newuserid -- join for new user
LEFT JOIN coprincipal newp ON newp.userid = bob.newuserid -- insert new user here to validate against coprincipal
WHERE p.userid IS NULL;


/*ONLY USE IF ALL ARE GOING TO THE SAME EMPLOYEE, if not read comment below*/
UPDATE cotimecard tc
SET principalid = bob.newuserid
FROM (
	SELECT tc.timecardid AS timecardid,
		CASE 
			WHEN newp.username IS NOT NULL
				THEN 'Valid User ID'
			ELSE 'Invalid User ID'
			END AS newusername,
		bob.newuserid AS newuserid
	FROM cotimecard tc
	LEFT JOIN coprincipal p ON p.userid = tc.principalid
	LEFT JOIN (
		SELECT (/* REPLACE ME --> */ 9999999999999 /* <-- REPLACE ME */) AS newuserid
		) bob ON bob.newuserid = bob.newuserid
	LEFT JOIN coprincipal newp ON newp.userid = bob.newuserid
	WHERE p.userid IS NULL
	) bob
WHERE bob.timecardid = tc.timecardid
/* un-comment the line below, and select the "baduserid" from the diagnostic, and replace the XXXX with it. This will make the update only affect the "baduserid" you picked. 
 --    AND tc.princiapalid = XXXX <-- Use this if there are multiple userids with this issue in cotimecard
