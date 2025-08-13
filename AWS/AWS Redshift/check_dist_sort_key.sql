-- Alternative way to check table structure
SELECT 
    "schema",
    "table", 
    diststyle,
    sortkey1
FROM svv_table_info 
WHERE "table" = '$TABLE_NAME';


ALTER TABLE $TABLE_NAME 
ALTER DISTKEY operator_code;


ALTER TABLE $TABLE_NAME 
ALTER COMPOUND SORTKEY (timestamp, operator_code, content_ref_id);