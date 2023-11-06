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
	/* This CTE is used to compare the start and end time of rentals based on their end date, and their start dates to gauge whether there will be overlapping availability.
It takes advantage of the row_number() function to compare the first reservation items, rds, to the items that were scheduled after them. The filters and case whens
look for items where the end of the first reservation overlaps with the beginning of the next reservation. This includes items with no end date and the SQL
assums the end date is in the year 3000. The case whens are using to distinguish between the two types of overlapping availability which are:

1. items with no end date that have reservations scheduled during them or at the same time as them,
    or where they start inbetween a stopped reservation
    
2. Items with an end date, where they overlap, but one or the other is stopped. The first variation
    where the first item ends inbetween a stopped reservation is sometimes fixable in the system,
    and the second, where the first reservation is stopped, and the next one is on-going and started before the
    end of the first reservation, requires SQL.
*/
AS (
	SELECT ri.rentalitemnumber AS curritemnumber,
		ri.rentaltypeid,
		ri.rentalitemid,
		Array [rds.reservationid, rde.reservationid] AS reservationids, -- res item ids
		-- begin ultimate case whens
		CASE 
			WHEN (
					-- opt1
					rde.contractstart < rds.contractend
					AND rde.contractstart != rds.contractstart
					AND rde.STATE = 2 -- next res ongoing
					AND rds.STATE NOT IN (1, 2) -- previous is stopped
					)
				THEN ARRAY [rde.contractstart, rde.contractend, 'current res starts before previous res end', 'Current res start overlap, previous stopped', 'test1']
			WHEN (
					-- opt2
					rds.STATE = 2 -- previous res ongoing
					AND rde.STATE = 2 -- current res ongoing
					AND rde.contractstart < rds.contractend -- current res starts before the last one ends
					AND rde.contractstart != rds.contractstart
					AND rds.noenddate = 1 -- previous res has no end date
					)
				THEN ARRAY [rds.contractstart, rds.contractend, 'previous item no end date and current started after', 'Previous item has no end date, Current Item Open', 'test2']
			WHEN (
					-- opt3
					rde.contractstart = rds.contractstart
					AND (
						rds.STATE = 2
						OR rde.STATE = 2
						)
					)
				THEN ARRAY [rde.contractstart, rde.contractend, 'reservations started same day, select items', CASE when rde.state = 2 and rds.state != 2 then 'Same day conflict, Current Item Open' when rds.state = 2 and rde.state != 2 then 'Same day conflict, Previous Item Open' WHEN rds.state = 2 and rde.state = 2 then 'Same day conflict, Both reservations on-going' END, 'test3 -- need to build out case when or add an additional to select which one is ongoing']
			WHEN (
					-- opt4
					rds.contractend > rde.contractstart
					AND rds.STATE = 2
					AND rde.STATE NOT IN (1, 2)
					)
				THEN ARRAY [rds.contractstart, rds.contractend, 'previous reservation ends after the start of the current res and current is stopped', 'Previous res ends after Current, Current is stopped', 'test4']
			END AS textfields,
		--
		-- begin number fields from case when
		--
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.contractstart != rds.contractstart
					AND rde.STATE = 2 -- next res ongoing
					AND rds.STATE NOT IN (1, 2) -- previous is stopped
					)
				THEN ARRAY [rde.reservationitemid]
			WHEN (
					rds.STATE = 2 -- previous res ongoing
					AND rde.STATE = 2 -- current res ongoing
					AND rde.contractstart < rds.contractend -- current res starts before the last one ends
					AND rde.contractstart != rds.contractstart
					AND rds.noenddate = 1 -- previous res has no end date
					)
				THEN ARRAY [rds.reservationitemid]
			WHEN (
					rde.contractstart = rds.contractstart
					AND (
						rds.STATE = 2
						OR rde.STATE = 2
						)
					)
				THEN ARRAY [rde.reservationitemid, CASE when rde.state = 2 and rds.state != 2 then rde.reservationid when rds.state = 2 and rde.state != 2 then rds.reservationid WHEN rds.state = 2 and rde.state = 2 then rds.reservationid END]
			WHEN (
					rds.contractend > rde.contractstart
					AND rds.STATE = 2
					AND rde.STATE NOT IN (1, 2)
					)
				THEN ARRAY [rds.reservationitemid]
			END AS intfields
	FROM rerentalitem ri
	INNER JOIN reservationdates rds ON rds.itemid = ri.rentalitemid
	LEFT JOIN reservationdates rde ON rde.itemid = rds.itemid -- join used to find the next reservation that occurred after a given reservation
		AND rde.resnumber = rds.resnumber + 1
	--
	-- LOGIC FOR ITEMS WITH AVAILABILITY ISSUES STARTS 
	--
	WHERE (
			-- Where the current reservation is ongoing, and starts before the end of the previous reservation (Needs SQL)
			--
			rde.contractstart < rds.contractend
			AND rde.contractstart != rds.contractstart
			AND rde.STATE = 2 -- next res ongoing
			AND rds.STATE NOT IN (1, 2) -- previous is stopped
			)
		OR (
			-- Where both reservations are ongoing, and the current one was started after a previous reservation with no end date (Sometimes fixable on front-end)
			--
			rds.STATE = 2 -- previous res ongoing
			AND rde.STATE = 2 -- current res ongoing
			AND rde.contractstart < rds.contractend -- current res starts before the last one ends
			AND rde.contractstart != rds.contractstart
			AND rds.noenddate = 1 -- previous res has no end date
			)
		OR (
			-- Where both reservations start on the same day and one or the other is still on-going (Neeeds SQL)
			--
			rde.contractstart = rds.contractstart
			AND (
				rds.STATE = 2
				OR rde.STATE = 2
				)
			)
		OR (
			-- Where the previous reservation is ongoing, and stops after the beginning of the next reservation (Sometimes fixable on front-end)
			--
			rds.contractend > rde.contractstart
			AND rds.STATE = 2
			AND rde.STATE NOT IN (1, 2)
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
		rds.contractstart || ' --> ' || rds.contractend || ' || ' || rde.contractstart || ' --> ' || rde.contractend,
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
		'10000-09-30' || ' --> ' || '10000-09-30' || ' || ' || '30000-09-30' || ' --> ' || '30000-09-30',
		1 AS curritemstate,
		1 AS nextritemstate
	FROM rerentalitem ri
	LEFT JOIN rereservationitem rei ON rei.rentalitemid = ri.rentalitemid
	WHERE rei.reservationitemid IS NULL
	),
resitems
AS (
	SELECT 'Previous Res #' || rdsr.reservationnumber::VARCHAR || ' overlaps with Current Res #' || rder.reservationnumber AS reservation_numbers,
		pr.curritemnumber AS rental_item,
		pr.textfields [4] AS conflict_type,
		--
		ar.newitemnumber,
		CASE 
			WHEN left(ar.newitemnumber, 2) = left(pr.curritemnumber, 2)
				THEN 'Matched Types'
			ELSE 'No Match'
			END AS perfectmatch,
		(ar.availstart || ' --> ') AS availability_start,
		--
		('[ ' || pr.textfields [1] || ' ===> ' || pr.textfields [2] || ' ]') AS badres_period,
		--
		(' <-- ' || ar.availend) AS availability_end,
		--
		ar.newitemnumber AS newitem_number,
		pr.textfields [3] AS description,
		pr.textfields,
		ar.*,
		row_Number() OVER (
			PARTITION BY pr.rentalitemid ORDER BY CASE 
					WHEN left(ar.newitemnumber, 2) = left(pr.curritemnumber, 2)
						THEN '0'
					ELSE '1'
					END ASC,
				ar.newitemnumber ASC
			) AS optionnumber
	FROM problemrentals pr
	INNER JOIN rereservation rdsr ON pr.reservationids [1] = rdsr.reservationid
	LEFT JOIN rereservation rder ON pr.reservationids [2] = rder.reservationid
	LEFT JOIN availablerentals ar ON pr.textfields [1] >= ar.availstart
		AND ar.availend >= pr.textfields [2]
	)
SELECT *
FROM resitems
WHERE optionnumber = 1
