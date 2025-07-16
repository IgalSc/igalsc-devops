#!/bin/bash
BUCKET_NAME="your-bucket-name"  # Replace with your actual bucket name
PROFILE="your-aws-profile"  # Replace with your AWS CLI profile name
STORAGE_CLASS="your-storage-class"  # Replace with desired storage class (e.g., STANDARD, INTELLIGENT_TIERING)
# List all objects and process in parallel
aws s3api list-objects-v2 \
  --bucket $BUCKET_NAME \
  --profile $PROFILE \
  --query 'Contents[].Key' \
  --output text | \
  tr '\t' '\n' | \
  parallel -j 50 aws s3api copy-object \
    --bucket $BUCKET_NAME \
    --copy-source $BUCKET_NAME/{} \
    --key {} \
    --storage-class $STORAGE_CLASS \
    --metadata-directive COPY \
    --profile $PROFILE \