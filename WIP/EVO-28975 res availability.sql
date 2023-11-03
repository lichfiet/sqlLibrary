WITH reservationdates
AS (
	SELECT *,
		row_Number() OVER (
			PARTITION BY resi.reservationid ORDER BY resi.contractstartdate
			) AS resnumber
	FROM rerentalitem ri
	INNER JOIN rereservationitem resi ON resi.rentalitemid = ri.rentalitemid
	ORDER BY resi.reservationid
	)
SELECT r.*
FROM rereservation r
LEFT JOIN reservationdates rds ON rds.reservationid = r.reservationid
LEFT JOIN reservationdates rde ON rde.reservationid = rds.reservationid
	AND rds.resnumber = rde.resnumber + 1
