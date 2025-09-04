SELECT 
    digests.digest_text,
    COUNT_STAR AS exec_count,
    SUM_TIMER_WAIT/1000000000000 AS total_time_sec,
    AVG_TIMER_WAIT/1000000000000 AS avg_time_sec,
    SUM_LOCK_TIME/1000000000000 AS total_lock_time_sec,
    SUM_ROWS_EXAMINED AS rows_examined,
    SUM_ROWS_SENT AS rows_sent
FROM 
    performance_schema.events_statements_summary_by_digest AS digests
ORDER BY 
    total_time_sec DESC
LIMIT 10;