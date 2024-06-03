#!/bin/bash

# Fetch volume IDs and store them in volumes.txt
aws ec2 describe-volumes --filters Name=status,Values=available --query 'Volumes[*].VolumeId' --profile={PROFILE_NAME_HERE} --region us-east-1 --output text | tr '\t' '\n' > volumes.txt

# Process each volume ID
while read -r volume_id; do
    echo "Deleting volume: $volume_id"
    aws ec2 delete-volume --volume-id "$volume_id" --profile={PROFILE_NAME_HERE} --region us-east-1
done < volumes.txt
