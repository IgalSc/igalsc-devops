#!/bin/bash

# Set your AWS profile, region, and bucket name
PROFILE="profile_name"
REGION="us-east-1"
BUCKET="bucket_name"

aws s3 mv ./ $BUCKET \
  --profile "$PROFILE" \
  --region $REGION \
  --recursive \
  --cache-control no-cache,no-store,must-revalidate,public


echo "Run complete."
