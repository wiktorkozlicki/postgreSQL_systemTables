# postgreSQL_systemTables
Northwind in PostgreSQL Database schema exploration using system catalogs and views .

# About the database

    The Northwind database is a sample database used by Microsoft to demonstrate the features of some of its products,
    including SQL Server and Microsoft Access. The database contains the sales data for Northwind Traders,
    a fictitious specialty foods exportimport company. 

Here I used version suited for PostgreSQL, which is available via this Github repository:
https://github.com/pthom/northwind_psql


# Goal of the project

Today's goal was to show examples of queries that provide metadata about the database, using information_schema view and pg_catalog system catalog.


With them we can run SQL queries that will show us, for example:

- How many tables are in the database
- How many rows and columns are in each table
- How are the tables connected, checking primary to foreign keys connections


Note that queries I presented are universal and will work in any PostgreSQL database!

# List of tables

Let's start with simple query that will list all tables in the database: 

    SELECT table_name from information_schema.tables
    WHERE table_schema like 'public';
Using WHERE clause show only 'public' tables. This will hide system tables that contain metadata, which may not be important during regular use of database.

 We used information_schema view:

The information schema consists of a set of views that contain information about the objects defined in the current database. The information schema is defined in the SQL standard and can therefore be expected to be portable and remain stable — unlike the system catalogs, which are specific to PostgreSQL and are modeled after implementation concerns. 

Note: You can get silimar results using \d command in psql terminal. The SQL method can be useful as a part of more complex queries, as shown in later example. 

# Table of rows and columns for each table
# Number of Rows 
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
Query with use of Common Table Expressions (CTE) and XML functions to select number of rows.

# Number of Columns

    SELECT TABLE_NAME,
      COUNT(*) AS NUMBER_OF_COLUMNS
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA LIKE 'public'
    GROUP BY TABLE_NAME
    ORDER BY NUMBER_OF_COLUMNS DESC;
It is easy to count number of columns for each table because information about each column in the database is stored in the information_schema.columns view.

# Number of Columns and Rows in one query

    WITH NORTHWIND_TABLES AS
    (
    	SELECT TABLE_SCHEMA,
    	TABLE_NAME
    	FROM INFORMATION_SCHEMA.TABLES
    	WHERE TABLE_NAME NOT LIKE '%pg_%'AND TABLE_SCHEMA LIKE 'public'
    ),
    NORTHWIND_COLUMNS_COUNT AS
    (
    	SELECT TABLE_NAME,
    	COUNT(TABLE_NAME) AS NUMBER_OF_COLUMNS
    	FROM INFORMATION_SCHEMA.COLUMNS
    	GROUP BY TABLE_NAME
    )	
    SELECT
    NORTHWIND_TABLES.TABLE_NAME,
    (
    	XPATH
     (
    	 'row/c/text()',QUERY_TO_XML
      (
    	  FORMAT('select count(*) as c from %I.%I',NORTHWIND_TABLES.TABLE_SCHEMA,NORTHWIND_TABLES.TABLE_NAME
    			)
    	  ,FALSE,TRUE,''
      )
     )
    )[1]::text::int AS number_of_rows,
    NORTHWIND_COLUMNS_COUNT.NUMBER_OF_COLUMNS
    FROM NORTHWIND_TABLES
    INNER JOIN NORTHWIND_COLUMNS_COUNT ON NORTHWIND_TABLES.TABLE_NAME = NORTHWIND_COLUMNS_COUNT.TABLE_NAME
    ORDER BY "number_of_rows" DESC;
Merging two previous queries using inner join.

# All Primary key - Foreign Key relations

This query will be more complex. We'll use PG_CATALOG system catalogs:

The system catalogs are the place where a relational database management system stores schema metadata, such as information about tables and columns, and internal bookkeeping information. PostgreSQL's system catalogs are regular tables. 


We want a query that will return:

- Primary Key to Foreign Key connection name
- Location of primary key (table and column name)
- Location of foreign key (table and column name)
- Data type of the key


I created 4 virtual tables using CTE:

- CONNECTION_TABLE - selects ID's of primarykey column and foreign key column for every Foreign Key connection (line 7). This will be used in following tables.

- FOREIGN_KEY_TABLES - selects ID's and table names for every table containing foreign key used in Foreign Key connection.

- PRIMARY_KEY_TABLES - selects ID's and table names for every table containing primary key used in Foreign Key connection.

- TABLE_COLUMNS - selects all columns from public tables, with the name of the table they are part of, their position in the table, and their data type.


Here's the query:

     WITH
     	CONNECTION_TABLE AS
    	(SELECT *,
    			UNNEST(CONFKEY) AS FOREIGN_KEY_COLUMN,
    			UNNEST(CONKEY) AS PRIMARY_KEY_COLUMN
    		FROM PG_CATALOG.PG_CONSTRAINT
    		WHERE CONTYPE like 'f'),
  		
  	FOREIGN_KEY_TABLES AS
  	(SELECT DISTINCT PGC.OID,
  			PGC.RELNAME
  		FROM PG_CATALOG.PG_CLASS PGC
  		INNER JOIN CONNECTION_TABLE CT ON CT.CONFRELID = PGC.OID),
  		
  	PRIMARY_KEY_TABLES AS
  	(SELECT DISTINCT PGC.OID,
  			PGC.RELNAME
  		FROM PG_CATALOG.PG_CLASS PGC
  		INNER JOIN CONNECTION_TABLE CT ON CT.CONRELID = PGC.OID),
  		
  	TABLE_COLUMNS AS
  	(SELECT TABLE_NAME,
  			COLUMN_NAME,
  			ORDINAL_POSITION,
  			DATA_TYPE
  		FROM INFORMATION_SCHEMA.COLUMNS
  		WHERE TABLE_NAME not like '%pg_%' )
		
    SELECT CT.CONNAME AS CONNECTION_NAME,
    	PGC_P.RELNAME AS PRIMARY_KEY_TABLE,
    	TC_P.COLUMN_NAME PRIMARY_KEY_COLUMN,
    	PGC_F.RELNAME AS FOREIGN_KEY_TABLE,
    	TC_F.COLUMN_NAME FOREIGN_KEY_COLUMN,
    	TC_P.DATA_TYPE AS KEY_DATA_TYPE
    	
    FROM CONNECTION_TABLE CT
    INNER JOIN FOREIGN_KEY_TABLES PGC_F ON CT.CONFRELID = PGC_F.OID
    INNER JOIN PRIMARY_KEY_TABLES PGC_P ON CT.CONRELID = PGC_P.OID
    INNER JOIN TABLE_COLUMNS TC_F ON PGC_F.RELNAME = TC_F.TABLE_NAME
    	AND CT.FOREIGN_KEY_COLUMN = TC_F.ORDINAL_POSITION
    INNER JOIN TABLE_COLUMNS TC_P ON PGC_P.RELNAME = TC_P.TABLE_NAME
    	AND CT.PRIMARY_KEY_COLUMN = TC_P.ORDINAL_POSITION
    
    ORDER BY primary_key_table, foreign_key_table
Notice the difference between CT.CONFRELID (FOREIGN_KEY_TABLES) and CT.CONRELID (PRIMARY_KEY_TABLES) in CTE part of the query.

__

That's all for today. Thanks for reading!

 Sources:

- Northwind database for Postgres:
https://github.com/pthom/northwind_psql
    
- What is Northwind Database:
https://www.unife.it/ing/informazione/Basi_dati/lucidi/materiali-di-laboratorio/esercizi-sql-base-di-dati-nothwind
    
- PostgreSQL: Documentation: 16: Chapter 37. The Information Schema:
https://www.postgresql.org/docs/current/information-schema.html
    
- PostgreSQL: Documentation: 16: Chapter 53. System Catalogs:
https://www.postgresql.org/docs/current/catalogs.html
    
- How do you find the row count for all your tables in Postgres:
https://stackoverflow.com/questions/2596670/how-do-you-find-the-row-count-for-all-your-tables-in-postgres

