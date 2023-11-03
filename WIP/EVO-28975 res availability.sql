WITH reservationdates
AS (
	SELECT resi.rentalitemid AS itemid,
		*,
		row_Number() OVER (
			PARTITION BY resi.reservationid ORDER BY resi.contractenddate ASC
			) AS resnumber,
		CASE 
			WHEN resi.noenddate = 1
				THEN '2055-01-01 01:00:01'
			ELSE TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD')
			END AS contractstart,
		TO_CHAR(resi.contractenddate, 'YYYY-MM-DD') AS contractend
	FROM rerentalitem ri
	INNER JOIN rereservationitem resi ON resi.rentalitemid = ri.rentalitemid
	ORDER BY resi.reservationid
	)
SELECT ri.rentalitemnumber,
	rds.contractend AS availstart,
	rde.contractstart AS availend,
	--	rds.contractstartdate || ' --> ' || rds.contractenddate,
	--	rde.contractstartdate || ' --> ' || rde.contractenddate,
	rds.STATE AS curritemstate,
	rde.STATE AS nextritemstate,
	ri.*
FROM rerentalitem ri
INNER JOIN reservationdates rds ON rds.itemid = ri.rentalitemid
LEFT JOIN reservationdates rde ON rde.itemid = rds.itemid
	AND rde.resnumber = rds.resnumber + 1
WHERE (
		rde.contractstart < rds.contractend
		AND rde.STATE = 2
		OR (
			(
				rds.noenddate = 1
				OR rds.contractend < rde.contractstart
				)
			AND rds.STATE = 2
			AND rde.contractstart < rds.contractend
			)
		)
