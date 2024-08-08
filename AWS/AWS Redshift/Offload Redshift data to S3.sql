# Run the following query on the production redshift cluster.  
# Make sure to update the “till_august_2022’ preffix to the relevant month when running the query 

unload ('select * from {$table_name} where date < cast(dateadd(day, -180, sysdate) as date)') 
to 's3://{$bucket_name}/{$prefics}/{$file_name}' 
iam_role 'arn:aws:iam::{$AWS_ACCOUNT}:role/{$iam_role_name}' 
CSV delimiter ',' 
gzip; 

# Next, run the following command, to delete the data from the table 

delete from events_v4 where date < cast(dateadd(day, -180, sysdate) as date) 