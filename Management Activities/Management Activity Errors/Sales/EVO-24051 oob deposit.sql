-- EVO-24051 Out of Balance Deal Unfinalize Update
--
-- SQL Description: sql sets payment amount to 0 after system erroneously created additional deposit on deal unfinalize.
-- How to Use: replace the xxxxx on the line that says replace me, then run
-- Jira Key/CR Number: EVO-24051 | https://lightspeeddms.atlassian.net/jira/software/c/projects/EVO/issues/EVO-24051
-- SQL Statement:

UPDATE cocommoninvoicepayment cip
SET amount = 0
FROM (
	SELECT cip.commoninvoicepaymentid AS id,
		*
	FROM cocommoninvoicepayment cip
	INNER JOIN cocommoninvoice ci ON ci.commoninvoiceid = cip.commoninvoiceid
	INNER JOIN mabusinessaction ba ON CAST(ci.invoicenumber AS VARCHAR) = ba.invoicenumber
	WHERE ci.invoicenumber = xxxxx -- <- Replace me
		AND ba.STATUS = 2
	) bob
WHERE bob.id = cip.commoninvoicepaymentid
