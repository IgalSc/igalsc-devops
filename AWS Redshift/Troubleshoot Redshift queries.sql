select * from stl_load_errors
--where raw_line like '%e5f0aaa9-8aad-48b5-9572-14b0cf69e19f%'
order by starttime desc;

select * from SVL_QUERY_SUMMARY
where query = '$QUERY_ID';


select * from STL_CONNECTION_LOG
where pid = '$PID'
"recordtime" = date('$DATE')
and dbname = '$DBNAME'
and username = '$USERNAME'