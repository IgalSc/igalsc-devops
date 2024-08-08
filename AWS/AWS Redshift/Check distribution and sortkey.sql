SELECT
    a.attname AS column_name,
    CASE 
        WHEN a.attisdistkey THEN 'Distribution Key'
        ELSE 'Not Distribution Key'
    END AS key_type
FROM
    pg_namespace n
JOIN
    pg_class c ON n.oid = c.relnamespace
JOIN
    pg_attribute a ON c.oid = a.attrelid
WHERE
    c.relkind = 'r' -- 'r' stands for regular table
    AND n.nspname = 'schema_name'  -- replace 'schema_name' with the name of your schema
    AND c.relname = 'table_name'  -- replace 'table_name' with the name of your table
    AND a.attisdistkey;

   
SELECT
    a.attname AS column_name,
    CASE
        WHEN a.attsortkeyord > 0 THEN 'Ascending Sort Key'
        WHEN a.attsortkeyord < 0 THEN 'Descending Sort Key'
        ELSE 'Not Sort Key'
    END AS key_type,
    ABS(a.attsortkeyord) as sortkey_order
FROM
    pg_namespace n
JOIN
    pg_class c ON n.oid = c.relnamespace
JOIN
    pg_attribute a ON c.oid = a.attrelid
WHERE
    c.relkind = 'r'
    AND n.nspname = 'schema_name'  -- replace 'schema_name' with the name of your schema
    AND c.relname = 'table_name'  -- replace 'table_name' with the name of your table
    AND a.attsortkeyord <> 0
ORDER BY ABS(a.attsortkeyord);