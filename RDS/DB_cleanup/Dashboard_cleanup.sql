delete from [$DB_NAME].[dbo].[FEATURE_ACCESS_LOG]
where SESSION_LOG_ID in
(SELECT SESSION_LOG_ID
  FROM [$DB_NAME].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180)

delete FROM [$DB_NAME].[dbo].[FEATURE_ACCESS_LOG]
  where DATEDIFF(day,START_TIME,GETDATE()) between 0 and 180

delete
  FROM [$DB_NAME].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180

delete from [$DB_NAME2].[dbo].[FEATURE_ACCESS_LOG]
where SESSION_LOG_ID in
(SELECT SESSION_LOG_ID
  FROM [$DB_NAME2].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180)

delete FROM [$DB_NAME2].[dbo].[FEATURE_ACCESS_LOG]
  where DATEDIFF(day,START_TIME,GETDATE()) between 0 and 180

delete
  FROM [$DB_NAME2].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180

delete from [$DB_NAME3].[dbo].[FEATURE_ACCESS_LOG]
where SESSION_LOG_ID in
(SELECT SESSION_LOG_ID
  FROM [$DB_NAME3].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180)

delete FROM [$DB_NAME3].[dbo].[FEATURE_ACCESS_LOG]
  where DATEDIFF(day,START_TIME,GETDATE()) between 0 and 180

delete
  FROM [$DB_NAME3].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180

delete from [$DB_NAME4].[dbo].[FEATURE_ACCESS_LOG]
where SESSION_LOG_ID in
(SELECT SESSION_LOG_ID
  FROM [$DB_NAME4].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180)

delete FROM [$DB_NAME4].[dbo].[FEATURE_ACCESS_LOG]
  where DATEDIFF(day,START_TIME,GETDATE()) between 0 and 180

delete
  FROM [$DB_NAME4].[dbo].[SESSION_LOG]
  where DATEDIFF(day,START_TIMESTAMP,GETDATE()) between 0 and 180