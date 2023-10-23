-- oooooooooooo oooooo     oooo   .oooooo.                       .oooo.     oooooooo  ooooooooo  .ooooo.    .ooooo.  
-- `888'     `8  `888.     .8'   d8P'  `Y8b                    .dP""Y88b   dP""""""" d"""""""8' 888' `Y88. d88'   `8.
--  888           `888.   .8'   888      888                         ]8P' d88888b.         .8'  888    888 Y88..  .8'
--  888oooo8       `888. .8'    888      888                       .d8P'      `Y88b       .8'    `Vbood888  `88888b. 
--  888    "        `888.8'     888      888      8888888        .dP'           ]88      .8'          888' .8'  ``88b
--  888       o      `888'      `88b    d88'                   .oP     .o o.   .88P     .8'         .88P'  `8.   .88P
-- o888ooooood8       `8'        `Y8bood8P'                    8888888888 `8bd88P'     .8'        .oP'      `boood8' 
--
-- Forked from Chris Kulaga's Original SQL
-- 
-- Modified by: 
--      Trevor Lichfield
--      Spencer Lichfield 
--      John Scott
--      *add name here*
--                                                                                                                                                                        
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
--  
-- This SQL is used to diagnose common problems and issue relating to and caused by EVO-25798. 
-- It includes multiple diagnostics in this order:
--
--      Output 1: Incorrect Storeid / Accountingid or luids
--
--      Output 2: Checks paid, partially paid, and not paid when they should be.
--          This includes checks paid 
--
--
--                                                                                    
--                                                                                                                                                                        
--                                                                                                                                                                        
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
-- 
--
--
--   .g8""8q.                mm                          mm            
-- .dP'    `YM.              MM                          MM       __,  
-- dM'      `MM `7MM  `7MM mmMMmm `7MMpdMAo.`7MM  `7MM mmMMmm    `7MM  
-- MM        MM   MM    MM   MM     MM   `Wb  MM    MM   MM        MM  
-- MM.      ,MP   MM    MM   MM     MM    M8  MM    MM   MM        MM  
-- `Mb.    ,dP'   MM    MM   MM     MM   ,AP  MM    MM   MM        MM  
--   `"bmmd"'     `Mbod"YML. `Mbmo  MMbmmd'   `Mbod"YML. `Mbmo   .JMML.
--                                  MM                                 
--                                .JMML.                               
--
--
--
--  Corrects erroneous packing slip invoice, storeid = 0
--
UPDATE glsltransaction gls
SET storeid = 1,
	storeidluid = data.good_id
FROM (
	SELECT gls.sltrxid,
		gls.storeid,
		s.storeidluid AS good_id
	FROM glsltransaction gls
	INNER JOIN costore s USING (storeid)
	WHERE s.storeid = 1
	) data
WHERE gls.storeid = 0
	AND accttype = 2;
--                                                                                                                                                                        
-- mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm mmmmm
-- 
--
--   .g8""8q.                mm                          mm              
-- .dP'    `YM.              MM                          MM              
-- dM'      `MM `7MM  `7MM mmMMmm `7MMpdMAo.`7MM  `7MM mmMMmm     pd*"*b.
-- MM        MM   MM    MM   MM     MM   `Wb  MM    MM   MM      (O)   j8
-- MM.      ,MP   MM    MM   MM     MM    M8  MM    MM   MM          ,;j9
-- `Mb.    ,dP'   MM    MM   MM     MM   ,AP  MM    MM   MM       ,-='   
--   `"bmmd"'     `Mbod"YML. `Mbmo  MMbmmd'   `Mbod"YML. `Mbmo   Ammmmmmm
--                                  MM                                   
--                                .JMML.                                 
--
--
SELECT /* Remaining Amount*/ ROUND((sl.remainingamt * .0001), 2) AS remaining,
	--
	/* Invoice Amount */ ROUND((sl.docamt * .0001), 2) AS docamt,
	--
	/* Paid from Checks */ ROUND(sum(amtpaidthischeck * .0001), 2) AS paidsofar,
	--
	/* Correct Remaing Amount */
	CASE 
		WHEN voids.id IS NOT NULL
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0
			THEN 0
		WHEN ((docamt - sum(amtpaidthischeck))) != docamt
			THEN ROUND(((docamt - sum(amtpaidthischeck)) * .0001), 2)
		ELSE 0
		END AS corr_remain,
	/* */
	/* Invoice Number */ sl.documentnumber,
	/* Invoice Description */ sl.description,
	--
	/* SLTRX State */
	CASE 
		WHEN voids.id IS NOT NULL -- if part of the voided checks list
			THEN 1
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) <= 0 -- If the sum of payments <= 0
			THEN 4 --FULLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) != docamt -- If the sum of payments = part of the invoice amt
			THEN 2 -- PARTIALLY PAID
		WHEN ((docamt - sum(amtpaidthischeck)) * .0001) = docamt --- IF the sum of check payments = 0
			THEN 1 -- UNPAID
		ELSE 0 -- Panic if you get a zero
		END AS STATE,
	/* */
	sl.sltrxstate AS oldstate,
	--
	sl.sltrxid AS identifier,
	CASE 
		WHEN voids.id IS NOT NULL
			THEN voids.id
		ELSE sl.sltrxid
		END AS sltrxidentifier
--
FROM apcheckinvoicelist il
LEFT JOIN glsltransaction sl ON il.apinvoiceid = sl.sltrxid
LEFT JOIN (
	SELECT il.apinvoiceid AS id, -- ap invoice id or sltrxid
		sl.documentnumber
	FROM apcheckinvoicelist il -- list of invoices that have had checks paid on them
	INNER JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid -- join on checkheader to see the check states
	INNER JOIN glsltransaction sl ON sl.sltrxid = il.apinvoiceid -- join to reference the glsl info (remaining amounts and whatnot)
	WHERE sl.docamt != sl.remainingamt -- Where remaining amount != the invoice amount
		AND sltrxstate NOT IN (9, 4) -- Not voided or already paid
		AND sl.accttype = 2 -- Is an ap invoice
	GROUP BY il.apinvoiceid,
		sl.documentnumber
	/* Whether all checks are voided */
	HAVING sum(CASE 
				WHEN ch.voidedflag = 2
					THEN 1
				ELSE 0
				END) = count(il.apinvoiceid)::INT
	) voids ON voids.id = sl.sltrxid
INNER JOIN apvendor v ON v.vendorid = sl.acctid
LEFT JOIN apcheckheader ch ON ch.apcheckheaderid = il.apcheckheaderid
WHERE (
		(
			sltrxstate NOT IN (9)
			AND ch.voidedflag = 0
			)
		OR voids.id IS NOT NULL
		)
	AND v.vendornumber = 410928 -- Makes sure we don't included voided checks in the paid so far sum
GROUP BY apinvoiceid,
	sl.documentnumber,
	sl.description,
	sl.docamt,
	sl.remainingamt,
	sl.sltrxid,
	voids.id
HAVING sum(amtpaidthischeck) != (docamt - remainingamt) OR voids.id IS NOT NULL;
