-- EVO-39893
--
-- SQL Description: updates to new value
-- How to Use: No Changes needed, copy and pase
-- Jira Key/CR Number: EVO-39893 | https://lightspeeddms.atlassian.net/browse/EVO-39893
-- SQL Statement:

-- Please make sure financial account has appropriate GL Account assigned
UPDATE glbankreconciliation br
SET glaccountid = bob.newglaccountid -- set to financial accounts gl account 
FROM (
	SELECT br.bankreconciliationid AS id, -- bank rec id
		fa.glaccountid AS newglaccountid, -- gl account from financial account info
		facoa.acctdept AS newglaccount -- gl accounts account code
	FROM glbankreconciliation br -- bank rec table
	LEFT JOIN glchartofaccounts coa ON coa.acctdeptid = br.glaccountid -- join on chart of accounts to /compare/ with the bank rec
	INNER JOIN glfinancialaccount fa ON fa.accountid = br.financialaccountid -- join on financial account to link to bank rec
	INNER JOIN glchartofaccounts facoa ON facoa.acctdeptid = fa.glaccountid -- join on chart of accounts again to link to financial account
	WHERE coa.acctdeptid IS NULL -- if there isn't a matching account in chart of accounts when compared to bank rec
	) bob -- idenfitying the results from the select as bob
WHERE br.bankreconciliationid = bob.id -- where bank rec id from bob is equal to the real one
