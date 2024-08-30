#!/bin/bash
PROFILE="profile_name"
REGION="your-region"
CLUSTER="your-cluster"

aws redshift modify-cluster \
    --cluster-identifier $CLUSTER \
    --number-of-nodes 2 \
    --profile $PROFILE \
    --region $REGION
