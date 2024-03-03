WITH NORTHWIND_TABLES AS
(SELECT TABLE_SCHEMA,
		TABLE_NAME
	FROM INFORMATION_SCHEMA.TABLES
	WHERE TABLE_NAME NOT LIKE '%pg_%'
		AND TABLE_SCHEMA LIKE 'public' )
SELECT TABLE_NAME,
	(XPATH('row/c/text()',
		   QUERY_TO_XML(
			   FORMAT('select count(*) as c from %I.%I',TABLE_SCHEMA,TABLE_NAME),
			   FALSE,
			   TRUE,
				''
		   )
		  )
	)[1]::text::int AS "number_of_rows"
FROM NORTHWIND_TABLES
ORDER BY "number_of_rows" DESC;
