-- Create a temporary table to store the column information
CREATE TEMPORARY TABLE temp_columns (
    table_schema VARCHAR(200),
    table_name VARCHAR(200),
    column_name VARCHAR(200),
    data_type VARCHAR(100),
    character_maximum_length INT,
    encoding VARCHAR(32),
    is_materialized_view BOOLEAN DEFAULT FALSE
);

-- Iterate over all the tables and columns
INSERT INTO temp_columns (table_schema, table_name, column_name, data_type, character_maximum_length, encoding, is_materialized_view)
SELECT
    n.nspname AS table_schema,
    c.relname AS table_name,
    a.attname AS column_name,
    t.typname AS data_type,
    CASE 
        WHEN a.attlen < 0 THEN a.atttypmod - 4
        ELSE a.attlen
    END AS character_maximum_length,
    CASE WHEN a.attencodingtype = 0 THEN 'none'
         WHEN a.attencodingtype = 1 THEN 'bytedict'
         WHEN a.attencodingtype = 2 THEN 'runlength'
         WHEN a.attencodingtype = 3 THEN 'text255'
         WHEN a.attencodingtype = 4 THEN 'text32k'
         ELSE 'unknown'
    END AS encoding,
    c.relkind = 'm' AS is_materialized_view
FROM
    pg_namespace n
    JOIN pg_class c ON n.oid = c.relnamespace
    JOIN pg_attribute a ON c.oid = a.attrelid
    JOIN pg_type t ON a.atttypid = t.oid
WHERE
    n.nspname = 'public' -- Replace with your actual schema name
    AND a.attnum > 0
    AND t.typname LIKE 'varchar%'
ORDER BY character_maximum_length ASC;

-- Check the selection
SELECT * FROM temp_columns;

-- Create a temporary table to store the ALTER statements
CREATE TEMPORARY TABLE temp_alter_statements (
    statement TEXT
);

-- Create a stored procedure to generate the ALTER statements
CREATE OR REPLACE PROCEDURE generate_alter_statements()
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    mv_definition TEXT;
BEGIN
    -- Generate ALTER statements for changing encoding to RAW for specific encodings
    FOR rec IN 
        (SELECT DISTINCT table_schema, table_name, column_name, is_materialized_view 
         FROM temp_columns
         WHERE encoding IN ('bytedict', 'runlength', 'text255', 'text32k'))
    LOOP
        IF NOT rec.is_materialized_view THEN
            INSERT INTO temp_alter_statements (statement)
            VALUES ('ALTER TABLE ' || quote_ident(rec.table_schema) || '.' || quote_ident(rec.table_name) || 
                    ' ALTER COLUMN ' || quote_ident(rec.column_name) || ' ENCODE RAW;');
        END IF;
    END LOOP;

    -- Generate ALTER statements for columns with length < 4096 to change the length
    FOR rec IN 
        (SELECT DISTINCT table_schema, table_name, column_name, is_materialized_view 
         FROM temp_columns
         WHERE character_maximum_length < 4096)
    LOOP
        IF NOT rec.is_materialized_view THEN
            INSERT INTO temp_alter_statements (statement)
            VALUES ('ALTER TABLE ' || quote_ident(rec.table_schema) || '.' || quote_ident(rec.table_name) || 
                    ' ALTER COLUMN ' || quote_ident(rec.column_name) || ' TYPE VARCHAR(4096);');
        ELSE
            -- Retrieve and store the definition of the materialized view
            SELECT definition INTO mv_definition
            FROM pg_matviews
            WHERE schemaname = rec.table_schema
              AND matviewname = rec.table_name;
              
            -- Drop the materialized view
            INSERT INTO temp_alter_statements (statement)
            VALUES ('DROP MATERIALIZED VIEW ' || quote_ident(rec.table_schema) || '.' || quote_ident(rec.table_name) || ';');
            
            -- Create the materialized view with the updated column definition
            INSERT INTO temp_alter_statements (statement)
            VALUES (
                'CREATE MATERIALIZED VIEW ' || quote_ident(rec.table_schema) || '.' || quote_ident(rec.table_name) || ' AS ' ||
                regexp_replace(mv_definition, quote_ident(rec.column_name) || '\s+VARCHAR\(\d+\)', quote_ident(rec.column_name) || ' VARCHAR(4096)', 'g')
            );
        END IF;
    END LOOP;
END $$;

-- Call the stored procedure to generate the statements
CALL generate_alter_statements();

-- Check the generated statements
SELECT * FROM temp_alter_statements;

-- Clean up the temporary tables
DROP TABLE temp_columns;
DROP TABLE temp_alter_statements;
