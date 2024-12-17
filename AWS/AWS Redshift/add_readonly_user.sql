# Create a readonly user and group in AWS Redshift
CREATE USER readonly_user PASSWORD 'PASSWORD_HERE';
CREATE GROUP readonly_group;

# Add the readonly user to the readonly group
ALTER GROUP readonly_group ADD USER readonly_user;

# Grant the readonly group access to the public schema
GRANT USAGE ON SCHEMA public TO GROUP readonly_group;

# Grant the readonly group select access to all tables in the public schema
GRANT SELECT ON ALL TABLES IN SCHEMA public TO GROUP readonly_group;

# Check the permissions of the readonly user
SELECT schemaname, tablename, 
       usename, 
       has_table_privilege(usename, schemaname || '.' || tablename, 'SELECT') AS has_select
FROM pg_tables, pg_user
WHERE usename = 'readonly_user'
  AND schemaname = 'public';