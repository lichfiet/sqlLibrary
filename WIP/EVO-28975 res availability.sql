/* INFORMATION:

The purpose of this diagnostic is to identify items with overlapping availability, where
one or the other can not be closed without changing the dates on the reservation, or assigning
the reservation to a new rental item, with availability for that time period. This SQL will
point out the conflicts, the type of conflict, as well as an applicable reservation with
availability for the reservation with the issues. By default the SQL will return all items
with availability issues.

INSTRUCTIONS:

To use, you can either copy and past the SQL and look for your item in the returned records,
or change the text that says CHANGE ME in the SQL below. */
WITH searchdata
AS (
	SELECT ('CHANGE ME') AS reservationnumber, -- Use this line to search for one reservation
		ARRAY ['CHANGE ME', 'CHANGE ME', '...'] AS reservationnumbers -- Use this line to search for multiple reservations
	),
reservationdates
	/*

This first CTE will select all reservation items for a reservation 

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
			END AS contractend,
		CASE 
			WHEN resi.state = 1
				THEN 'Future'
			WHEN resi.state = 2
				THEN 'Ongoing'
			WHEN resi.state = 3
				THEN 'idk'
			WHEN resi.state = 4
				THEN 'Stopped/Finalized'
			ELSE resi.state::varchar
			END AS STATUS,
		r.reservationnumber
	--
	FROM rerentalitem ri
	INNER JOIN rereservationitem resi ON resi.rentalitemid = ri.rentalitemid
	INNER JOIN rereservation r ON r.reservationid = resi.reservationid
	),
problemrentals
	/* This CTE is used to compare the start and end time of rentals based on their end date, and their start dates to gauge whether there will be overlapping availability.
It takes advantage of the row_number() function to compare the first reservation items, rds, to the items that were scheduled after them. The filters and case whens
look for items where any reservations overlap with one-another. The case whens are using to distinguish between the 4 types of overlapping availability which are:

1. Where the current reservation is ongoing, and starts before the end of the previous reservation (Needs SQL)
    
2. Where both reservations are ongoing, and the current one was started after a previous reservation with no end date (Sometimes fixable on front-end)

3. Where both reservations start on the same day and one or the other is still on-going (Neeeds SQL)

4. Where the previous reservation is ongoing, and stops after the beginning of the next reservation (Sometimes fixable on front-end)

There are two main case whens that return arrays, the first is the varchar fields, and the second is the int fields, the
query used to return information uses these fields as well as the availability finder. It will select the array[nth] item
for each piece of data because the  information returned is relative to the type of overlapping availability
*/
AS (
	SELECT ri.rentalitemnumber AS curritemnumber,
		ri.rentaltypeid,
		ri.rentalitemid,
		ri.storeid,
		Array [rds.reservationid, rde.reservationid] AS reservationids, -- res item ids
		Array [rds.status, rde.status] AS reservationstatus, -- status of reservations
		-- begin ultimate case whens
		CASE 
			WHEN (
					-- opt1
					rde.contractstart < rds.contractend
					AND rde.contractstart != rds.contractstart
					AND rde.STATE IN (1, 2) -- next res ongoing
					AND rds.STATE NOT IN (1, 2) -- previous is stopped
					)
				THEN ARRAY [rde.contractstart, rde.contractend, 'current res starts before previous res end', 'Reservation #' || rde.reservationnumber || ' started before reservation #' || rds.reservationnumber || ' ended', 'test1']
			WHEN (
					-- opt2
					rds.STATE IN (1, 2) -- previous res ongoing
					AND rde.STATE IN (1, 2) -- current res ongoing
					AND rde.contractstart < rds.contractend -- current res starts before the last one ends
					AND rde.contractstart != rds.contractstart
					AND rds.noenddate = 1 -- previous res has no end date
					)
				THEN ARRAY [rds.contractstart, rds.contractend, '', 'Reservation #' || rds.reservationnumber || ' has no end date and reservation #' || rde.reservationnumber || ' was started after it', 'test2']
			WHEN (
					-- opt3
					rde.contractstart = rds.contractstart
					AND (
						rds.STATE IN (1, 2)
						OR rde.STATE IN (1, 2)
						)
					)
				THEN ARRAY [rde.contractstart, rde.contractend, 'reservations started same day, select items', CASE when rde.state IN (1, 2) and rds.state NOT IN (1, 2) then 'Reservations #' || rds.reservationnumber || ' and #' || rde.reservationnumber || ' start on the same day, and #' || rde.reservationnumber || ' is not stopped' when rds.state IN (1, 2) and rde.state NOT IN (1, 2) then 'Reservations #' || rds.reservationnumber || ' and #' || rde.reservationnumber || ' start on the same day, and #' || rds.reservationnumber || ' is not stopped' WHEN rds.state IN (1, 2) and rde.state IN (1, 2) then 'Reservations #' || rds.reservationnumber || ' and #' || rde.reservationnumber || ' start on the same day, and both reservations are on-going' END, 'test3 -- need to build out case when or add an additional to select which one is ongoing']
			WHEN (
					-- opt4
					rds.contractend > rde.contractstart
					AND rds.STATE IN (1, 2)
					AND rde.STATE NOT IN (1, 2)
					)
				THEN ARRAY [rds.contractstart, rds.contractend, 'previous reservation ends after the start of the current res and current is stopped', 'Reservation #' || rds.reservationnumber || ' ends after reservation #' || rde.reservationnumber || ' which is currently stopped' ,'test4']
			END AS textfields,
		--
		-- begin number fields from case when
		--
		CASE 
			WHEN (
					rde.contractstart < rds.contractend
					AND rde.contractstart != rds.contractstart
					AND rde.STATE IN (1, 2) -- next res ongoing
					AND rds.STATE NOT IN (1, 2) -- previous is stopped
					)
				THEN ARRAY [rde.reservationitemid, rde.reservationid]
			WHEN (
					rds.STATE IN (1, 2) -- previous res ongoing
					AND rde.STATE IN (1, 2) -- current res ongoing
					AND rde.contractstart < rds.contractend -- current res starts before the last one ends
					AND rde.contractstart != rds.contractstart
					AND rds.noenddate = 1 -- previous res has no end date
					)
				THEN ARRAY [rds.reservationitemid, rds.reservationid]
			WHEN (
					rde.contractstart = rds.contractstart
					AND (
						rds.STATE IN (1, 2)
						OR rde.STATE IN (1, 2)
						)
					)
				THEN (
						CASE 
							WHEN rde.STATE IN (1, 2)
								AND rds.STATE NOT IN (1, 2)
								THEN ARRAY [rde.reservationitemid, rde.reservationid]
							WHEN rds.STATE IN (1, 2)
								AND rde.STATE NOT IN (1, 2)
								THEN ARRAY [rds.reservationitemid, rds.reservationid]
							WHEN rds.STATE IN (1, 2)
								AND rde.STATE IN (1, 2)
								THEN ARRAY [rds.reservationitemid, rds.reservationid]
							END
						)
			WHEN (
					rds.contractend > rde.contractstart
					AND rds.STATE IN (1, 2)
					AND rde.STATE NOT IN (1, 2)
					)
				THEN ARRAY [rds.reservationitemid, rds.reservationid]
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
			AND rde.STATE IN (1, 2) -- next res ongoing
			AND rds.STATE NOT IN (1, 2) -- previous is stopped
			)
		OR (
			-- Where both reservations are ongoing, and the current one was started after a previous reservation with no end date (Sometimes fixable on front-end)
			--
			rds.STATE IN (1, 2) -- previous res ongoing
			AND rde.STATE IN (1, 2) -- current res ongoing
			AND rde.contractstart < rds.contractend -- current res starts before the last one ends
			AND rde.contractstart != rds.contractstart
			AND rds.noenddate = 1 -- previous res has no end date
			)
		OR (
			-- Where both reservations start on the same day and one or the other is still on-going (Neeeds SQL)
			--
			rde.contractstart = rds.contractstart
			AND (
				rds.STATE IN (1, 2)
				OR rde.STATE IN (1, 2)
				)
			)
		OR (
			-- Where the previous reservation is ongoing, and stops after the beginning of the next reservation (Sometimes fixable on front-end)
			--
			rds.contractend > rde.contractstart
			AND rds.STATE IN (1, 2)
			AND rde.STATE NOT IN (1, 2)
			)
	),
availablerentals
	/* This case when is used to identify rental items, that do not have a schedule reservation within the time-frame of one of the reservations with issues
this is usually either the only reservation that is open of the two, or the previous reservation. Items that have no history at all will be populated*/
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
		rde.STATE AS nextritemstate,
		ri.storeid
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
		1 AS nextritemstate,
		ri.storeid
	FROM rerentalitem ri
	LEFT JOIN rereservationitem rei ON rei.rentalitemid = ri.rentalitemid
	WHERE rei.reservationitemid IS NULL
	),
resitems
AS (
	SELECT 'Rental Item: ' || pr.curritemnumber AS rental_item,
		pr.textfields [4] AS conflict_description,
		--
		'Availability for reservation #' || changeres.reservationnumber || ' exists on rental item: ' || ar.newitemnumber AS availability,
		CASE 
			WHEN ar.rentaltypeid = pr.rentaltypeid
				THEN 'Yes'
			ELSE 'No'
			END AS new_item_matches_type,
		'Availability: ' || ar.availstart || ' --> ' AS new_item_availability_start,
		--
		('[ ' || pr.textfields [1] || ' ===> ' || pr.textfields [2] || ' ]') AS bad_reservation_dates,
		--
		(' <-- ' || ar.availend) AS new_item_availability_end,
		--
		'To Resolve, Update Res #' || changeres.reservationnumber AS res_num_to_modify,
		ar.rentalitemid AS new_rentalitemid,
		pr.intfields [1] AS reservationitemid_to_update,
		'Prev' || ': ' || pr.reservationstatus [1] || ' || Curr' || ': ' || pr.reservationstatus [2] AS reservation_numbers,
		row_Number() OVER (
			PARTITION BY pr.rentalitemid ORDER BY CASE 
					WHEN ar.rentaltypeid = pr.rentaltypeid
						THEN '0'
					ELSE '1'
					END ASC,
				ar.newitemnumber ASC
			) AS optionnumber
	FROM problemrentals pr
	INNER JOIN rereservation rdsr ON pr.reservationids [1] = rdsr.reservationid
	LEFT JOIN rereservation rder ON pr.reservationids [2] = rder.reservationid
	LEFT JOIN rereservation changeres ON pr.intfields [2] = changeres.reservationid
	LEFT JOIN availablerentals ar ON pr.textfields [1] >= ar.availstart
		AND ar.availend >= pr.textfields [2]
	LEFT JOIN searchdata s ON 1 = 1
	--
	WHERE (
			CASE 
				WHEN s.reservationnumber = 'CHANGE ME'
					AND s.reservationnumbers = ARRAY ['CHANGE ME', 'CHANGE ME', '...']
					THEN 1
				WHEN s.reservationnumber != 'CHANGE ME'
					AND s.reservationnumber = rdsr.reservationnumber::VARCHAR
					THEN 1
				WHEN s.reservationnumber != 'CHANGE ME'
					AND s.reservationnumber = rder.reservationnumber::VARCHAR
					THEN 1
				WHEN s.reservationnumbers != ARRAY ['CHANGE ME', 'CHANGE ME', '...']
					AND rdsr.reservationnumber::VARCHAR = ANY (s.reservationnumbers)
					OR rder.reservationnumber::VARCHAR = ANY (s.reservationnumbers)
					THEN 1
				ELSE 0
				END
			) = 1
	ORDER BY pr.curritemnumber ASC
	)
SELECT *
FROM resitems ri
WHERE ri.optionnumber = 1
