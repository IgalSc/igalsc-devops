@ECHO OFF
break> D:\Dashboard_Cleanup.log
SET SERVER="$HOST"
SET LOGIN="$LOGIN"
SET PASSWORD="$PASSWORD"
SET INPUT="D:\Dashboard_cleanup.sql"
SET OUTPUT="D:\Dashboard_Cleanup.log"
ECHO %date% %time% > %OUTPUT%
"C:\Program Files\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD" -S %SERVER% -U %LOGIN% -P %PASSWORD% -i %INPUT% -o %OUTPUT%
exit 0