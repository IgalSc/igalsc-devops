-- Backup 

exec msdb.dbo.rds_backup_database 
@source_db_name='{$DB_name}', 
@s3_arn_to_backup_to='arn:aws:s3:::{$S3_bucket}/{$DB_name}.bak',
@overwrite_s3_backup_file=1,
@type='FULL';

-- Check task status

exec msdb.dbo.rds_task_status @task_id=5;


----Restore

exec msdb.dbo.rds_restore_database 	
@restore_db_name='{$DB_name}', 
@s3_arn_to_restore_from='arn:aws:s3:::{$S3_bucket}/{$DB_name}.bak';

Fix orphaned users

IF NOT EXISTS (SELECT name FROM sys.sql_logins WHERE name='{$DB_name}')
 BEGIN
  CREATE LOGIN {$login} WITH PASSWORD = '{$password}'
 END
ELSE
 BEGIN
  ALTER LOGIN {$login} WITH PASSWORD = '{$password}'
 END
ALTER USER {$login} WITH LOGIN = {$login}