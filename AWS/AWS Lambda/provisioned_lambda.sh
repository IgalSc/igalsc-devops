#!/bin/bash
# This script checks all AWS Lambda functions in a specified region for provisioned concurrency.
# It lists the functions and their versions that have provisioned concurrency configured.
# Requirements: AWS CLI, jq
# Usage: ./provisioned_lambda.sh
# Prompt for AWS profile and region
read -p "Enter AWS profile: " PROFILE
read -p "Enter AWS region: " REGION

echo ""
echo "Checking Lambda functions with provisioned concurrency in region $REGION using profile $PROFILE..."
echo ""

# Get list of all Lambda functions
FUNCTIONS=$(aws lambda list-functions \
  --region "$REGION" \
  --profile "$PROFILE" \
  --query 'Functions[*].FunctionName' \
  --output text)

COUNT=0
FOUND=0

for FUNCTION in $FUNCTIONS; do
  ((COUNT++))
  echo "[$COUNT] Checking function: $FUNCTION"

  # Get versions (excluding $LATEST)
  VERSIONS=$(aws lambda list-versions-by-function \
    --function-name "$FUNCTION" \
    --region "$REGION" \
    --profile "$PROFILE" \
    --query 'Versions[?Version!=`"$LATEST"`].Version' \
    --output text)

  for VERSION in $VERSIONS; do
    # Attempt to get provisioned concurrency config
    CONFIG=$(aws lambda get-provisioned-concurrency-config \
      --function-name "$FUNCTION" \
      --qualifier "$VERSION" \
      --region "$REGION" \
      --profile "$PROFILE" 2>&1)

    if [[ "$CONFIG" != *"ProvisionedConcurrencyConfigNotFoundException"* ]]; then
      echo "✅ Function: $FUNCTION, Version: $VERSION"
      echo "$CONFIG" | jq '.AllocatedProvisionedConcurrentExecutions'
      echo "----------------------------------------"
      ((FOUND++))
    fi
  done
done

echo ""
echo "Done. Found $FOUND Lambda version(s) with provisioned concurrency."