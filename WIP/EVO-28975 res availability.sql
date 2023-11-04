/* This first CTE will select all reservation items for a reservation 

It uses a row_number function to order the items based on their end dates.
The purpose of this is so we have something to reference when comparing the end of one
reservation, to the start of the next one, so we can gauge availability, and see if they
overlap at any point. The case when in the row_number function will treat rental items that
are stopped, but stil have a no-end-date flag enables, as if their end date is the day it
started, because that is how the system appears to view them. 

The same case when is used for finding the items start and end dates, because items that
are stopped with no end date have an end date = to 1000-01-01, so the case when populates
the date it was started as the stop date.
*/
WITH reservationdates
AS (
	SELECT resi.reservationitemid, -- reservationitemid of current reservation item
		resi.rentalitemid AS itemid, -- rentalitemid assigned to the reservation
		resi.STATE, -- state of the reservation item (active, closed, stopped, etc)
		resi.reservationid, -- reservationid of the current reservation item
		resi.noenddate, -- no end date flag
		--
		-- row number function to order the reservation items for a specific rental item based on their end dates
		row_Number() OVER (
			PARTITION BY resi.rentalitemid ORDER BY (
					CASE 
						WHEN resi.noenddate = 1 -- when there is no end date, date = distant future date
							THEN '30000-09-30'
						WHEN resi.noenddate = 1 -- when there is no end date but reservation is stopped, end date = start date
							AND resi.STATE NOT IN (1, 2)
							THEN TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD')
						ELSE TO_CHAR(resi.contractenddate, 'YYYY-MM-DD') -- else, use the end date
						END
					) ASC,
				TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD') ASC -- also order by start date for items where both have no end date, selects newest item
			) AS resnumber,
		--
		TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD') AS contractstart, -- start date of the reservation item to the day
		--
		-- Case when for the end date of the reservation, need for items stopped without an end date, or open items with no end date
		CASE 
			WHEN resi.noenddate = 1 -- when there is no end date, date = distant future date
				THEN '30000-09-30'
			WHEN resi.noenddate = 1 -- -- when there is no end date but reservation is stopped, end date = start date
				AND resi.STATE NOT IN (1, 2)
				THEN TO_CHAR(resi.contractstartdate, 'YYYY-MM-DD')
			ELSE TO_CHAR(resi.contractenddate, 'YYYY-MM-DD') -- else, use the end date
			END AS contractend
	--
	FROM rerentalitem ri
	INNER JOIN rereservationitem resi ON resi.rentalitemid = ri.rentalitemid
	),
problemrentals
AS (
	SELECT ri.rentalitemnumber AS curritemnumber,
		ri.rentaltypeid,
		ri.rentalitemid,
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
		CASE 
			WHEN rds.contractstart = rde.contractstart
				THEN 'Same day conflict'
			ELSE 'N/A'
			END AS startconflict
	FROM rerentalitem ri
	INNER JOIN reservationdates rds ON rds.itemid = ri.rentalitemid
	LEFT JOIN reservationdates rde ON rde.itemid = rds.itemid -- join used to find the next reservation that occurred after a given reservation
		AND rde.resnumber = rds.resnumber + 1
	--
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
		ri.rentalitemid,
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
	
	UNION -- to pull items with no history
	
	SELECT ri.rentalitemnumber AS newitemnumber,
		ri.itemdescription,
		ri.rentalitemid,
		ri.rentaltypeid,
		'10000-09-30' AS availstart,
		'30000-09-30' AS availend,
		'10000-09-30' || ' --> ' || '10000-09-30',
		'30000-09-30' || ' --> ' || '30000-09-30',
		1 AS curritemstate,
		1 AS nextritemstate
	FROM rerentalitem ri
	LEFT JOIN rereservationitem rei ON rei.rentalitemid = ri.rentalitemid
	WHERE rei.reservationitemid IS NULL
	),
resitems
AS (
	SELECT r.reservationnumber AS resnumber,
		pr.curritemnumber,
		ar.newitemnumber,
		CASE 
			WHEN left(ar.newitemnumber, 2) = left(pr.curritemnumber, 2)
				THEN 'Matched Types'
			ELSE 'No Match'
			END AS perfectmatch,
		pr.startconflict,
		ar.availstart || ' --> ' AS availabilitystart,
		'[ ' || pr.resitemstart || ' ===> ' || pr.resitemend || ' ]' AS badres_period,
		' <-- ' ||	ar.availend AS availabilityend,
		ar.newitemnumber AS newitem_number,
		row_Number() OVER (
			PARTITION BY pr.rentalitemid ORDER BY CASE 
					WHEN left(ar.newitemnumber, 2) = left(pr.curritemnumber, 2)
						THEN '0'
					ELSE '1'
					END ASC,
				ar.newitemnumber ASC
			) AS optionnumber,
		--		row_Number() OVER (partition by ar.rentalitemid ORDER BY pr.rentalitemid ASC
		--			) AS usednumber,
		ar.*
	FROM problemrentals pr
	INNER JOIN rereservation r ON pr.reservationid = r.reservationid
	LEFT JOIN availablerentals ar ON pr.resitemstart >= ar.availstart
		AND ar.availend >= pr.resitemend
		AND ar.rentaltypeid = pr.rentaltypeid
	)
SELECT *
FROM resitems
WHERE optionnumber = 1
