
#!/bin/bash

# Prompt user for input
read -p "Enter your AWS Account ID: " ACCOUNT_ID
read -p "Enter your AWS CLI profile name: " PROFILE
read -p "Enter the AWS Region (e.g. us-east-1): " REGION
read -p "Enter the name for the S3 bucket to store VPC Flow Logs: " BUCKET_NAME

# Check if bucket exists
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" --profile "$PROFILE" 2>/dev/null; then
  echo "✅ Bucket $BUCKET_NAME already exists."
else
  echo "🚀 Creating bucket $BUCKET_NAME..."

  if [ "$REGION" == "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --profile "$PROFILE"
  else
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint=$REGION \
      --profile "$PROFILE"
  fi
fi

# Apply bucket policy to allow VPC Flow Logs to write
echo "📦 Applying bucket policy to allow VPC Flow Logs to write..."
cat <<EOF > bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "vpc-flow-logs.amazonaws.com" },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "$ACCOUNT_ID"
        }
      }
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket "$BUCKET_NAME" \
  --policy file://bucket-policy.json \
  --profile "$PROFILE"

# Create IAM Trust Policy file (skip if role exists)
ROLE_EXISTS=$(aws iam get-role --role-name VPCFlowLogsRole --profile $PROFILE 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "Creating IAM Role: VPCFlowLogsRole"
  cat <<EOF > trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "Service": "vpc-flow-logs.amazonaws.com" },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  aws iam create-role \
    --role-name VPCFlowLogsRole \
    --assume-role-policy-document file://trust-policy.json \
    --profile $PROFILE

  aws iam attach-role-policy \
    --role-name VPCFlowLogsRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs \
    --profile $PROFILE
else
  echo "✅ IAM Role VPCFlowLogsRole already exists, skipping."
fi

# Get NAT Gateway ENI
echo "Finding NAT Gateway ENI..."
ENI_ID=$(aws ec2 describe-nat-gateways \
  --region $REGION \
  --profile $PROFILE \
  --query "NatGateways[0].NatGatewayAddresses[0].NetworkInterfaceId" \
  --output text)

if [ -z "$ENI_ID" ]; then
  echo "❌ No NAT Gateway ENI found. Exiting."
  exit 1
fi

echo "Found ENI: $ENI_ID"

# Create Flow Logs to S3 (no DeliverLogsPermissionArn needed)
echo "Creating VPC Flow Logs to bucket s3://$BUCKET_NAME/"
aws ec2 create-flow-logs \
  --resource-type NetworkInterface \
  --resource-ids $ENI_ID \
  --traffic-type ALL \
  --log-destination-type s3 \
  --log-destination arn:aws:s3:::$BUCKET_NAME/ \
  --region $REGION \
  --profile $PROFILE

echo "✅ VPC Flow Logs set up successfully to S3."
