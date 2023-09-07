-- Bank Reconciliation Diagnostic to Find OOBs
--
-- SQL Description: calculates oob amounts if applicable on bank recs 
-- How to Use: replace fa.name with financial statement name
-- Jira Key/CR Number: 
-- SQL Statement:

-- ALL that needs to be changed is the GL account / Financial Account name on lines 15 and 20

SELECT br.statementdate,
	sum(amtdebit) AS Debits,
	sum(amtcredit) AS Credits,
	br.previousstatementbalance, -- Previous Balance
	((br.previousstatementbalance + sum(amtdebit) - sum(amtcredit)) * .0001) AS calculatedbal, -- Balance calculated based on GL history
	(br.statementbalance * .0001) AS actualbal, -- Statement Balance in the Bank Rec
	abs((((br.previousstatementbalance + sum(amtdebit) - sum(amtcredit))) - (br.statementbalance)) * .0001) AS dif -- Difference between the calcualted balance and the actual statementbalance
FROM glhistory gh
INNER JOIN glbankreconciliation br ON br.bankreconciliationid = gh.reconciliationid
INNER JOIN glchartofaccounts coa ON coa.acctdeptid = gh.acctdeptid
INNER JOIN glfinancialaccount fa ON fa.glaccountid = coa.acctdeptid
WHERE (
		fa.name = 'BANK OF UTAH' --- Insert financial account name in place of the XXX 
		AND br.isclosed = 1
		)
	OR (
		--- OR
		coa.acctdept = 'XXX' --- Insert Gl Account Number
		AND br.isclosed = 1
		)
GROUP BY reconciliationid,
	br.statementdate,
	previousstatementbalance,
	br.statementbalance
HAVING (br.previousstatementbalance + sum(amtdebit) - sum(amtcredit)) != br.statementbalance
ORDER BY statementdate ASC;

-- Entries with recid that is not valid
SELECT *
FROM glhistory h
WHERE h.reconciliationid != 0
	AND h.reconciliationid NOT IN (
		SELECT bankreconciliationid
		FROM glbankreconciliation
		)
