SELECT 
    TABLE_NAME,
    INDEX_NAME,
    COLUMN_NAME,
    NON_UNIQUE,
    SEQ_IN_INDEX,
    COLLATION,
    CARDINALITY
FROM 
    information_schema.STATISTICS
WHERE 
    TABLE_SCHEMA = 'your_database_name'
    AND TABLE_NAME = 'your_table_name';