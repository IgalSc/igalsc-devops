SELECT
    indexdef
FROM
    pg_indexes
WHERE
    schemaname = 'public'  -- Replace 'public' with your schema name, if different
ORDER BY
    tablename, indexname;