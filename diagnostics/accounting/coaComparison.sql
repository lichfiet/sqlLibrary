-- need to modify to take input of storeids
--
-- COA Comparison, account missing from store
WITH counts
AS (
	SELECT count(coa.acctdept),
		coa.acctdept,
		1 AS test,
		avg(sequencenumber) AS seqnum
	FROM glchartofaccounts coa
	GROUP BY coa.acctdept
	),
average
AS (
	SELECT round(avg(count), 0) AS avgcount
	FROM counts
	)
SELECT 'account might be missing from another location, if they have matching chart of accounts' AS description,
	count,
	acctdept,
	avgcount AS avgnumofaccountoccurences,
	round(seqnum, - 2) AS avgsequencenum
FROM counts c
INNER JOIN average av ON 1 = 1
WHERE count != avgcount;
