#!/bin/bash

# Credentials
region="aws_region"
profile="profile_name"

# Create an invalidation
  echo "Creating invalidations for Distribution ID: {CF_ID_HERE}"

  aws cloudfront create-invalidation \
    --distribution-id {CF_ID_HERE} \
    --paths "/*" \
    --query 'Invalidation.Id' \
    --region "$region" \
    --profile "$profile" \
    --output text



echo "Invalidations submitted successfully!"