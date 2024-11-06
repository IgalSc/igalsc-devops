#!/bin/bash

# seting profile and region for aws cli
region="your-region"
profile="your-profile"

for distribution_id in $(aws cloudfront list-distributions --region "$region" --profile "$profile" --query 'DistributionList.Items[*].{Id: Id, Comment: Comment}' --output json | jq -r '.[] | select(.Comment | contains("ec-")) | .Id'); do
    aws cloudfront tag-resource --region "$region" --profile "$profile" --resource arn:aws:cloudfront::YOUR_ACCOUNT_ID:distribution/$distribution_id --tags 'Items=[{Key=YourTagKey,Value=YourTagValue}]'
done