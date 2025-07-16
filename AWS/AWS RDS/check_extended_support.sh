#!/bin/bash

# Script to check RDS instances for extended support enrollment status
# Usage: ./check_rds_extended_support.sh --profile <profile_name> --region <region_name>

set -e

# Default values
PROFILE=""
REGION=""

# Function to display usage
usage() {
    echo "Usage: $0 --profile <profile_name> --region <region_name>"
    echo "  --profile: AWS CLI profile name"
    echo "  --region:  AWS region (e.g., us-east-1)"
    echo "Example: $0 --profile myprofile --region us-east-1"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --region)
            REGION="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required parameters
if [[ -z "$PROFILE" || -z "$REGION" ]]; then
    echo "Error: Both --profile and --region are required"
    usage
fi

echo "Checking RDS instances for Extended Support enrollment in region: $REGION using profile: $PROFILE"
echo "======================================================================================="

# Check DB instances
instances_json=$(aws rds describe-db-instances \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'DBInstances[*].[DBInstanceIdentifier,Engine,EngineVersion,EngineLifecycleSupport]' \
    --output json)

# Check DB clusters (Multi-AZ clusters)
clusters_json=$(aws rds describe-db-clusters \
    --profile "$PROFILE" \
    --region "$REGION" \
    --query 'DBClusters[*].[DBClusterIdentifier,Engine,EngineVersion,EngineLifecycleSupport]' \
    --output json 2>/dev/null || echo "[]")

total_instances=0
total_clusters=0
extended_support_yes=0

# Process DB instances
if [[ "$instances_json" != "[]" ]]; then
    echo "DB Instances:"
    echo "$instances_json" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r db_id engine engine_version lifecycle_support; do
        ((total_instances++))
        
        if [[ "$lifecycle_support" == "open-source-rds-extended-support" ]]; then
            echo "  $db_id ($engine $engine_version): YES"
            ((extended_support_yes++))
        else
            echo "  $db_id ($engine $engine_version): NO"
        fi
    done
fi

# Process DB clusters
if [[ "$clusters_json" != "[]" ]]; then
    echo ""
    echo "DB Clusters:"
    echo "$clusters_json" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r cluster_id engine engine_version lifecycle_support; do
        ((total_clusters++))
        
        if [[ "$lifecycle_support" == "open-source-rds-extended-support" ]]; then
            echo "  $cluster_id ($engine $engine_version): YES"
            ((extended_support_yes++))
        else
            echo "  $cluster_id ($engine $engine_version): NO"
        fi
    done
fi

# Count totals using temporary files to work around subshell limitations
temp_file=$(mktemp)

# Count instances
if [[ "$instances_json" != "[]" ]]; then
    echo "$instances_json" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r db_id engine engine_version lifecycle_support; do
        echo "instance" >> "$temp_file"
        if [[ "$lifecycle_support" == "open-source-rds-extended-support" ]]; then
            echo "yes" >> "$temp_file"
        fi
    done
fi

# Count clusters
if [[ "$clusters_json" != "[]" ]]; then
    echo "$clusters_json" | jq -r '.[] | @tsv' | while IFS=$'\t' read -r cluster_id engine engine_version lifecycle_support; do
        echo "instance" >> "$temp_file"
        if [[ "$lifecycle_support" == "open-source-rds-extended-support" ]]; then
            echo "yes" >> "$temp_file"
        fi
    done
fi

# Calculate totals
if [[ -f "$temp_file" ]]; then
    total_count=$(grep -c "instance" "$temp_file" 2>/dev/null || echo 0)
    extended_support_yes=$(grep -c "yes" "$temp_file" 2>/dev/null || echo 0)
else
    total_count=0
    extended_support_yes=0
fi

# Clean up
rm -f "$temp_file"

echo ""
echo "======================================================================================="
echo "Summary:"
echo "Total DB instances/clusters: $total_count"
echo "Extended Support enabled: $extended_support_yes"
echo "Extended Support disabled: $((total_count - extended_support_yes))"

if [[ $total_count -eq 0 ]]; then
    echo ""
    echo "No RDS instances or clusters found in region $REGION"
fi