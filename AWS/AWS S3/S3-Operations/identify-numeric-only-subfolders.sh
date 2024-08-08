#!/bin/bash

# Set your AWS profile, region, and bucket name
PROFILE="profile_name"
REGION="us-east-1"
BUCKET="bucket_name"
PREFIX="files/media/"
OUTPUT_FILE="deleted_objects_log.csv"


aws s3api list-objects-v2 \
  --profile "$PROFILE" \
  --region us-east-1 \
  --bucket "$BUCKET" \
  --prefix "files/media/" \
  --delimiter "/" \
  --query 'CommonPrefixes[].Prefix' --output text | tr '\t' '\n' | grep -Eo '^files/media/[0-9]+/$' \
  >> "$OUTPUT_FILE"

echo "Run complete. Review the log of identified objects in $OUTPUT_FILE."
