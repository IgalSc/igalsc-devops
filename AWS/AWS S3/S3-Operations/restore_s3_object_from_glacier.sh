# !/bin/bash
# Restore S3 Object from Glacier Storage Class
aws s3api restore-object \
--bucket {$bucket_name} \
--key {$file_name} \
--restore-request 'Days=2,GlacierJobParameters={Tier=Standard}' \
--profile {$AWS_profile} \
--region {$AWS_region}

# Check Restore Status
aws s3api head-object \
  --bucket ${bucket_name} \
  --key ${file_name} \
  --profile ${AWS_profile} \
  --region ${AWS_region} | grep -i restore
# If the output shows "ongoing-request=true", the restore is still in progress.
# If the output shows "ongoing-request=false", the restore is complete.
