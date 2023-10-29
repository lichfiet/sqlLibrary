-- Added by Chris Kulaga   
-- Schema Surfer
-- Allows you to search the entire SQL server for column names and it's keywords
-- modfied to print out DBML format.
SELECT (
		CASE 
			WHEN row_number() OVER (
					PARTITION BY t.table_name ORDER BY c.column_name ASC
					) = '1'
				THEN ('Table ' || t.table_name || ' { ' || 'NEXTLINE ')
			ELSE ''
			END
		) || '    ' || c.column_name || ' ' || ' ' || REPLACE(c.data_type, ' ', '') || ' ' || '[' || CASE 
		WHEN c.is_nullable = 'YES'
			THEN 'null'
		ELSE 'not null'
		END || ']' || (
		CASE 
			WHEN row_number() OVER (
					PARTITION BY t.table_name ORDER BY c.column_name DESC
					) = '1'
				THEN (' NEXTLINE ' || ' } ')
			ELSE ''
			END
		)
FROM information_schema.tables t
INNER JOIN information_schema.columns c ON c.table_name = t.table_name
	AND c.table_schema = t.table_schema
WHERE t.table_name ilike 'cocustomer%' -- change table name here, or the start of table name (ie. ap, gl, apvendor, etc.) t
	AND t.table_schema NOT IN ('information_schema', 'pg_catalog')
	AND t.table_type = 'BASE TABLE'
ORDER BY t.table_name ASC
