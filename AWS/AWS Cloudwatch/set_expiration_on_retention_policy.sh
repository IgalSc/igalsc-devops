# This script identifies Cloudwatch Log Groups 
# without expiration on the retention policy 
# and sets it to be 1 month

#!/bin/bash

region="your-region"
profile="your-profile"

for log_group in $(aws logs describe-log-groups \
                   --region $region \
                   --profile $profile \
                   --query 'logGroups[?retentionInDays==null].[logGroupName]' \
                   --output text);
do
    aws logs put-retention-policy \
             --region $region \
             --profile $profile \
             --log-group-name "$log_group" \
             --retention-in-days 30
done