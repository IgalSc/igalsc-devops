SELECT
  d.datname AS database_name,
  pg_size_pretty(pg_database_size(d.datname)) AS size
FROM
  pg_database d
ORDER BY
  pg_database_size(d.datname) DESC;