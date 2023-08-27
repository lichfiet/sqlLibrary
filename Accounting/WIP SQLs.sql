-- select to find user information with SQL

SELECT p.username,
	name,
	storename,
	email,
	value AS CMF,
	p.userid
FROM coprincipal p
INNER JOIN costore s ON s.storeid = p.storeid
INNER JOIN copreference pr ON pr.storeid = s.storeid
WHERE id = 'shop-DealerID'
	AND name ilike '%%' -- put name inbetween parenthesis
	AND value ilike '%%' -- (not required) put CMF inebwteen parenthesis 
	AND value != ''
	AND p.userid = 536377792379200351;

SELECT p.username,
	name,
	p.userid,
	CASE 
		WHEN rolename = 'AP_1099_FORMS'
			THEN 'AP Report: 1099 Forms'
		WHEN rolename = 'AP_CANNED_REPORTS_AGING_REPORT'
			THEN 'AP Report: AP Aging Report'
		WHEN rolename = 'AP_CANNED_REPORTS_CASH_FORECAST_REPORT'
			THEN 'AP Report: Cach Forecast Report'
		WHEN rolename = 'AP_CANNED_REPORTS_CHECK_REGISTER_REPORT'
			THEN 'AP Report: Check Register Report'
		WHEN rolename = 'AP_CANNED_REPORTS_VENDOR_DATA_CSV'
			THEN 'AP Report: Vendor Data Export'
		WHEN rolename = 'AP_ENTER_VENDOR_INVOICES'
			THEN 'AP Function: Vendor Invoice'
		WHEN rolename = 'AP_VENDOR_INQUIRY'
			THEN 'AP Function: Vendor Inquiry'
		WHEN rolename = 'AP_VOID_VENDOR_CHECK'
			THEN 'AP Function: Void Payment'
		ELSE rolename
		END AS permission,
	CASE 
		WHEN rolename = 'AP_1099_FORMS'
			THEN 'Able to print 1099 Forms'
		WHEN rolename = 'AP_CANNED_REPORTS_AGING_REPORT'
			THEN 'Able to print AP Aging Report'
		WHEN rolename = 'AP_CANNED_REPORTS_CASH_FORECAST_REPORT'
			THEN 'AP Report: Cach Forecast Report'
		WHEN rolename = 'AP_CANNED_REPORTS_CHECK_REGISTER_REPORT'
			THEN 'AP Report: Check Register Report'
		WHEN rolename = 'AP_CANNED_REPORTS_VENDOR_DATA_CSV'
			THEN 'AP Report: Vendor Data Export'
		WHEN rolename = 'AP_ENTER_VENDOR_INVOICES'
			THEN 'AP Function: Vendor Invoice'
		WHEN rolename = 'AP_VENDOR_INQUIRY'
			THEN 'AP Function: Vendor Inquiry'
		WHEN rolename = 'AP_VOID_VENDOR_CHECK'
			THEN 'AP Function: Void Payment'
		ELSE rolename
		END AS description,
	ROW_NUMBER() OVER (
		ORDER BY rolename ASC
		) row
FROM coprincipal p
INNER JOIN costore s ON s.storeid = p.storeid
INNER JOIN coprincipalrole r ON r.userid = p.userid
WHERE name ilike '%%' -- put name inbetween parenthesis
	AND p.userid = 536377792379200351 -- userid
	AND rolename NOT ilike '%VR%'
	AND rolename ilike '%%'
