import boto3
import json
from urllib.parse import quote_plus

# Settings
aws_access_key_id = '$AWS_ACCESS_KEY_ID'
aws_secret_access_key = '$AWS_SECRET_ACCESS_KEY'
# aws_session_token = 'YOUR_AWS_SESSION_TOKEN'  # Optional if using temporary credentials
region_name = '$AWS_REGION'

source_bucket = '$BUCKET_NAME'
source_prefix = 'api-logs/'
output_prefix = 'api/'  # Where to store the final flat JSONs

# Initialize S3 with credentials
s3 = boto3.client(
    's3',
    region_name=region_name,
    aws_access_key_id=aws_access_key_id,
    aws_secret_access_key=aws_secret_access_key,
#    aws_session_token=aws_session_token  # Optional
)

# List all log files
paginator = s3.get_paginator('list_objects_v2')
pages = paginator.paginate(Bucket=source_bucket, Prefix=source_prefix)

for page in pages:
    for obj in page.get('Contents', []):
        key = obj['Key']
        if not key.endswith('.json'):
            continue

        log_obj = s3.get_object(Bucket=source_bucket, Key=key)
        log_data = json.loads(log_obj['Body'].read())

        # Skip failed or bad responses
        if log_data.get('response_status') != 200:
            continue

        path = log_data.get('path', '').lstrip('/')
        query = log_data.get('query', '')
        response_body = log_data.get('response_body', '{}')

        # Encode query parameters into a safe filename
        query_suffix = quote_plus(query) if query else 'default'
        output_key = f"{output_prefix}{path}/{query_suffix}.json"

        print(f"→ Uploading {output_key}")
        s3.put_object(
            Bucket=source_bucket,
            Key=output_key,
            Body=response_body.encode('utf-8'),
            ContentType='application/json'
        )
