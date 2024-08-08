#!/bin/bash

# Set your AWS profile, region, and bucket name
PROFILE="profile_name"
REGION="us-east-1"
BUCKET="bucket_name"
PREFIX="files/media/"
OUTPUT_FILE="deleted_objects_log.csv"

# Create a temporary file for subfolders
TEMP_SUBFOLDERS=$(mktemp)

# Prepare the output file and write the header
echo "Bucket,Key" > "$OUTPUT_FILE"

# List all numeric-only subfolders and save to temporary file
aws s3api list-objects-v2 --profile "$PROFILE" --region "$REGION" --bucket "$BUCKET" --prefix "$PREFIX" --delimiter "/" --query 'CommonPrefixes[].Prefix' --output text | tr '\t' '\n' | grep -Eo '^files/media/[0-9]+/$' > "$TEMP_SUBFOLDERS"

# Read from the temporary file for subfolders
while IFS= read -r SUBFOLDER; do
    # Construct the prefix to target specific objects
    DELETE_PREFIX="${SUBFOLDER}videos/mezzanine/"

    # Use a temporary file for objects to delete
    TEMP_OBJECTS=$(mktemp)

    # List all objects under the deletion path and save to temporary file
    aws s3api list-objects-v2 --profile "$PROFILE" --region "$REGION" --bucket "$BUCKET" --prefix "${DELETE_PREFIX}" --query 'Contents[].Key' --output text > "$TEMP_OBJECTS"

    # Check if the temporary file is empty
    if [ -s "$TEMP_OBJECTS" ]; then
        # Delete each object and log it to the CSV file
        while IFS= read -r OBJECT; do
            aws s3api delete-object --profile "$PROFILE" --region "$REGION" --bucket "$BUCKET" --key "$OBJECT"
            if [ $? -eq 0 ]; then
                echo "$BUCKET,$OBJECT" >> "$OUTPUT_FILE"
                echo "Deleted $OBJECT"
            else
                echo "Failed to delete $OBJECT"
            fi
        done < "$TEMP_OBJECTS"
    else
        echo "No objects found in $DELETE_PREFIX"
    fi

    # Clean up the temporary file for objects
    rm "$TEMP_OBJECTS"
done < "$TEMP_SUBFOLDERS"

# Clean up the temporary file for subfolders
rm "$TEMP_SUBFOLDERS"

echo "Deletion complete. Review the log of deleted objects in $OUTPUT_FILE."
