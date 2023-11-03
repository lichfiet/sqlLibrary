WITH reservationdates
AS (
	SELECT resi.rentalitemid AS itemid,
		*,
		row_Number() OVER (
			PARTITION BY resi.rentalitemid ORDER BY (
					CASE 
						WHEN resi.noenddate = 1
							THEN '30000-09-30'
						ELSE resi.contractenddate
						END
					) ASC
			) AS resnumber,
		TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD') AS contractstart,
		CASE 
			WHEN resi.noenddate = 1
				THEN '30000-09-30'
			WHEN resi.noenddate = 1
				AND resi.STATE NOT IN (1, 2)
				THEN TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD')
			ELSE TO_CHAR(resi.contractenddate, 'YYYY-MM-DD')
			END AS contractend
	FROM rerentalitem ri
	INNER JOIN rereservationitem resi ON resi.rentalitemid = ri.rentalitemid
	ORDER BY resi.reservationid
	),
problemrentals
AS (
	SELECT ri.rentalitemnumber,
		ri.itemdescription,
		rds.contractend AS availstart,
		rde.contractstart AS availend,
		--	rds.contractstartdate || ' --> ' || rds.contractenddate,
		--	rde.contractstartdate || ' --> ' || rde.contractenddate,
		rds.STATE AS curritemstate,
		rde.STATE AS nextritemstate,
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.STATE = 2
					)
				THEN rde.reservationid
			ELSE rds.reservationid
			END AS reservationid,
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.STATE = 2
					)
				THEN rde.reservationitemid
			ELSE rds.reservationitemid
			END AS resitemid,
		-- problem rentals dates start
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.STATE = 2
					)
				THEN rde.contractstart
			ELSE rds.contractstart
			END AS resitemstart,
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.STATE = 2
					)
				THEN rde.contractend
			ELSE rds.contractend
			END AS resitemend,
		ri.*
	FROM rerentalitem ri
	INNER JOIN reservationdates rds ON rds.itemid = ri.rentalitemid
	LEFT JOIN reservationdates rde ON rde.itemid = rds.itemid
		AND rde.resnumber = rds.resnumber + 1
	-- Where the previous reservation has an end date after our start date
	WHERE rde.contractstart < rds.contractend
		AND rde.STATE = 2
		-- Where a reservation was started after a reservation with no end date
		OR (
			(
				rds.noenddate = 1
				OR rds.contractend < rde.contractstart
				AND rde.contractstart != rde.contractend
				)
			AND rds.STATE = 2
			AND rde.contractstart < rds.contractend
			)
	),
availablerentals
AS (
	SELECT ri.rentalitemnumber AS newitemnumber,
		ri.itemdescription,
		rds.resnumber,
		rde.resnumber,
		ri.rentaltypeid,
		CASE 
			WHEN rds.noenddate = 1
				THEN '30000-09-30'
			WHEN rde.contractstart IS NULL
				THEN rds.contractend
			ELSE rds.contractend
			END AS availstart,
		CASE 
			WHEN rds.noenddate = 1
				THEN rde.contractstart
			WHEN rde.contractstart IS NULL
				AND rds.noenddate != 1
				THEN '30000-09-30'
			ELSE rde.contractstart
			END AS availend,
		rds.contractstart || ' --> ' || rds.contractend,
		rde.contractstart || ' --> ' || rde.contractend,
		rds.STATE AS curritemstate,
		rde.STATE AS nextritemstate
	FROM rerentalitem ri
	INNER JOIN reservationdates rds ON rds.itemid = ri.rentalitemid
	LEFT JOIN reservationdates rde ON rde.itemid = rds.itemid
		AND rde.resnumber = rds.resnumber + 1
	)
SELECT r.reservationnumber,
	ar.availstart AS newitem_availabilitystart,
	'<',
	pr.resitemstart AS badres_contractstart,
	pr.resitemend AS badres_contractend,
	'<',
	ar.availend AS newitem_availabilityend,
	ar.newitemnumber AS newitem_number,
	ar.*
FROM problemrentals pr
INNER JOIN rereservation r ON pr.reservationid = r.reservationid
LEFT JOIN availablerentals ar ON pr.resitemstart >= ar.availstart
	AND ar.availend >= pr.resitemend
	AND ar.rentaltypeid = pr.rentaltypeid
