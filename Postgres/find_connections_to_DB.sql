SELECT
  pid,
  usename,
  datname,
  client_addr,
  application_name,
  backend_start,
  state,
  query
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY backend_start DESC;
