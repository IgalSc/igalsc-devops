# Description: Lambda function to proxy requests to the API
import json
import boto3
import uuid
import urllib3
from datetime import datetime
from base64 import b64decode

s3 = boto3.client('s3')
http = urllib3.PoolManager()
BUCKET = '$BUCKET_NAME'

def lambda_handler(event, context):
    request_id = str(uuid.uuid4())
    timestamp = datetime.utcnow().isoformat()

    method = event['requestContext']['http']['method']
    path = event['rawPath']
    query = event.get('rawQueryString') or ''
    original_headers = event.get('headers', {}) or {}

    # Filter out AWS-injected headers
    excluded_headers = {
        'host', 'x-forwarded-for', 'x-forwarded-port', 'x-forwarded-proto',
        'x-amzn-trace-id', 'x-api-key', 'x-amz-date', 'x-amz-security-token'
    }

    headers = {k: v for k, v in original_headers.items() if k.lower() not in excluded_headers}
    body = event.get('body', None)
    is_base64 = event.get('isBase64Encoded', False)

    if is_base64 and body:
        body = b64decode(body)
    elif body:
        body = body.encode('utf-8')

    url = f"https://$API_URL{path}"
    if query:
        url += f"?{query}"

    try:
        response = http.request(
            method,
            url,
            body=body,
            headers=headers,
            timeout=10.0,
            preload_content=False
        )
        resp_body = response.read()
        resp_headers = dict(response.headers)
        status_code = response.status

    except Exception as e:
        print(f"Proxy error: {e}")
        return {
            "statusCode": 502,
            "body": f"Proxy error: {str(e)}"
        }

    # Clean up headers for frontend compatibility
    cleaned_headers = {k.lower(): v for k, v in resp_headers.items()}
    cleaned_headers.pop('content-encoding', None)  # Prevent misleading gzip header
    cleaned_headers['content-type'] = 'application/json'  # Ensure correct MIME type

    # Log to S3
    log_entry = {
        'timestamp': timestamp,
        'request_id': request_id,
        'method': method,
        'path': path,
        'query': query,
        'forwarded_url': url,
        'request_headers': headers,
        'request_body': body.decode('utf-8', errors='replace') if body else '',
        'response_status': status_code,
        'response_headers': cleaned_headers,
        'response_body': resp_body.decode('utf-8', errors='replace')
    }

    key = f"api-logs/{timestamp}_{request_id}.json"
    s3.put_object(Bucket=BUCKET, Key=key, Body=json.dumps(log_entry))

    return {
        "statusCode": status_code,
        "headers": cleaned_headers,
        "body": resp_body.decode('utf-8', errors='replace')
    }