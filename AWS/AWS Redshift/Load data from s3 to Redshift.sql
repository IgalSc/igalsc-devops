
COPY events_old
FROM 's3://{$s3_bucket}/{$prefics}/{$file_name}'  
iam_role 'arn:aws:iam::{$AWS_Account}:role/{$iam_role_name}' 
json 'auto'; 