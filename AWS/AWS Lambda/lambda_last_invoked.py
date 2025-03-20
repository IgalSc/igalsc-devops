# Check the last invocation time of all Lambda functions in an AWS account
# Usage: python lambda_last_invoked.py --profile <AWS profile> --region <AWS region>

import boto3
from datetime import datetime, timezone
from tabulate import tabulate
import argparse

# Argument parser for AWS profile selection
parser = argparse.ArgumentParser(description='List AWS Lambda functions and their last invocation times')
parser.add_argument('--profile', type=str, required=True, help='AWS named profile to use')
parser.add_argument('--region', type=str, required=True, help='AWS region to use')
args = parser.parse_args()

# Set AWS session with specified profile and region
session = boto3.Session(profile_name=args.profile, region_name=args.region)
lambda_client = session.client('lambda')
logs_client = session.client('logs')

# Get list of Lambda functions
functions = []
response = lambda_client.list_functions()
functions.extend(response['Functions'])

while 'NextMarker' in response:
    response = lambda_client.list_functions(Marker=response['NextMarker'])
    functions.extend(response['Functions'])

# Retrieve last invocation from CloudWatch logs
def get_last_invocation(function_name):
    log_group = f'/aws/lambda/{function_name}'
    try:
        streams_response = logs_client.describe_log_streams(
            logGroupName=log_group,
            orderBy='LastEventTime',
            descending=True,
            limit=1
        )
        streams = streams_response.get('logStreams', [])
        if streams and 'lastEventTimestamp' in streams[0]:
            timestamp = streams[0]['lastEventTimestamp']
            return datetime.fromtimestamp(timestamp / 1000, timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'), timestamp
        else:
            return 'No invocations found', 0
    except logs_client.exceptions.ResourceNotFoundException:
        return 'No logs found', 0

# Collect results
data = []
for fn in functions:
    name = fn['FunctionName']
    last_invoked, timestamp = get_last_invocation(name)
    data.append([name, last_invoked, timestamp])

# Sort by last invocation timestamp, descending
data.sort(key=lambda x: x[2], reverse=True)

# Print table without timestamp column
print(tabulate([[row[0], row[1]] for row in data], headers=['Lambda Function', 'Last Invoked'], tablefmt='github'))
